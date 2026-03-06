# 在 MongoDB 建模 1 对 N 关系的基本方法

（文章转载自 MongoDB数据库）

很多初学者认为在 MongoDB 中进行“一对多”建模的唯一方法是将子文档数组嵌入到父文档中，但事实并非如此。仅仅因为您可以嵌入文档，并不意味着您应该嵌入文档。设计 MongoDB 模式时，需要从一个在使用 SQL 和规范化表时永远不会考虑的问题开始：关系的基数是什么？不那么正式地说：您需要更细致地描述您的“一对多”关系：是“一对几个”、“一对多”还是“一对数”？根据具体情况，可以使用不同的格式来建模关系。

下面讨论建模一对 N 关系的三种基本方法，同时还介绍更复杂的模式设计，包括非规范化和双向引用，并给出一些建议，帮助您在建模单个一对 N 关系时做出选择。

## 基础示例：嵌入（适合“一对几个/一对少数”）

“一对多”的一个例子可能是一个人的地址。这是嵌入的一个很好的用例。可以将地址放入 Person 对象内部的数组：

```js
db.person.findOne()
{
  name: 'Kate Monster',
  ssn: '123-456-7890',
  addresses: [
    { street: '123 Sesame St', city: 'Anytown', cc: 'USA' },
    { street: '123 Avenue Q', city: 'New York', cc: 'USA' }
  ]
}
```

优点：无需执行单独查询即可获取嵌入的细节。缺点：无法作为独立实体访问嵌入的细节。例如在任务跟踪系统中，把任务嵌入到人员文档会使像“显示明天到期的所有任务”这样的查询变得复杂。

## 基础示例：引用数组（适合“一对多”）

一个例子是备件订购系统中的产品零件。每个产品可能有数百个备件，但绝不会超过几千个，这是引用的一个很好的使用案例。可以将零件的 ObjectID 放在产品文档的数组中。

注：示例中使用简短的 2 字节 ObjectID（便于阅读），实际使用中为 12 字节 ObjectID。

每个零件都有自己的文档：

```js
db.parts.findOne()
{
  _id: ObjectID('AAAA'),
  partno: '123-aff-456',
  name: '#4 grommet',
  qty: 94,
  cost: 0.94,
  price: 3.99
}
```

每个产品都有自己的文档，其中包含了构成该产品的零件的 ObjectID 引用数组：

```js
db.products.findOne()
{
  name: 'left-handed smokeshifter',
  manufacturer: 'Acme Corp',
  catalog_number: 1234,
  parts: [
    ObjectID('AAAA'), // reference to the #4 grommet above
    ObjectID('F17C'),
    ObjectID('D2AA'),
    // etc
  ]
}
```

在应用层级联接以检索特定产品的零件：

```js
// Fetch the Product document identified by this catalog number
product = db.products.findOne({ catalog_number: 1234 });

// Fetch all the Parts that are linked to this Product
product_parts = db.parts.find({ _id: { $in: product.parts } }).toArray();
```

为了高效操作，需在 `products.catalog_number` 上建立索引。请注意 `parts._id` 上始终有索引，因此查询高效。

引用方式的优点：每个部分是独立文档，可以独立搜索和更新。代价是需要第二个查询来获取零件详细信息。额外的好处是允许多个产品使用相同的部件，使一对 N 模式变为 N 对 N，而无需连接表。

## 基础示例：父引用（适合“一对数 / one-to-squillions”）

“one-to-squillions”的例子可能是收集不同机器的日志消息的事件日志系统。任何主机都可能生成大量消息，可能会溢出单个文档大小限制（16 MB），即使存储的是 ObjectID。这时应使用“父引用”：在日志消息文档中存储主机的 ObjectID。

```js
db.hosts.findOne()
{
  _id: ObjectID('AAAB'),
  name: 'goofy.example.com',
  ipaddr: '127.66.66.66'
}

db.logmsg.findOne()
{
  time: ISODate("2014-03-28T09:42:41.382Z"),
  message: 'cpu is on fire!',
  host: ObjectID('AAAB') // Reference to the Host document
}
```

查找主机的最新 5000 条消息：

```js
// find the parent ‘host’ document
host = db.hosts.findOne({ ipaddr: '127.66.66.66' }); // assumes unique index

// find the most recent 5000 log message documents linked to that host
last_5k_msg = db.logmsg.find({ host: host._id }).sort({ time: -1 }).limit(5000).toArray();
```

## 回顾（基础决定因素）

在设计时需要考虑两个关键因素：
- 一对 N 的 “N” 端实体是否需要独立？
- 关系的基数是多少：是“一对几个”、“一对多”还是“一对数”（one-to-squillions）？

基于这些因素，可以选择三种基本的一对 N 模式之一：
- 如果基数是一对多，并且不需要在父对象的上下文之外访问嵌入的对象，则嵌入 N 端。
- 如果基数是一对多或者 N 端对象需要独立，则使用对 N 端对象的引用数组。
- 如果基数为 one-to-squillions，请在 N 端文档中使用对父对象的引用（parent reference）。

---

## 中级：双向引用

可以结合两种技术，在模式中同时包含从“一”侧到“多”侧的引用和从“多”侧到“一”侧的引用。举例：任务跟踪系统，有 persons 集合和 tasks 集合，存在从 Person 到 Task 的一对 N 关系。应用程序需要跟踪人员拥有的所有任务（Person 引用 Task），同时在某些视图中需要快速找到每个任务的负责人（Task 引用 Person）。

Person 文档可能包含对 Task 的引用数组：

```js
db.person.findOne()
{
  _id: ObjectID("AAF1"),
  name: "Kate Monster",
  tasks: [
    ObjectID("ADF9"),
    ObjectID("AE02"),
    ObjectID("AE73"),
    // etc
  ]
}
```

Task 文档中包含对 Person 的引用：

```js
db.tasks.findOne()
{
  _id: ObjectID("ADF9"),
  description: "Write lesson plan",
  due_date: ISODate("2014-04-01"),
  owner: ObjectID("AAF1") // Reference to Person document
}
```

优点：能快速查找任务的所有者和人员的所有任务。缺点：当重新分配任务时需执行两次更新（更新 Person 文档中的引用数组以及 Task 文档中的 owner 字段），因此无法通过单个原子更新完成迁移。这在某些应用场景中是可以接受的，但需权衡。

---

## 中级：数据库非规范化（Denormalization）

非规范化可以消除某些情况下的应用程序级联接需求，但代价是在更新时增加复杂性。非规范化的核心原则是：一起访问的数据应该存储在一起。非规范化是复制字段或从现有字段派生新字段的过程。如果读取远多于更新，非规范化通常有意义。

### 非规范化示例：从多端到一端

对于前面的零件示例，可以将零件名称非规范化到 `products.parts[]` 数组中。未非规范化的产品文档如下：

```js
db.products.findOne()
{
  name: 'left-handed smokeshifter',
  manufacturer: 'Acme Corp',
  catalog_number: 1234,
  parts: [
    ObjectID('AAAA'),
    ObjectID('F17C'),
    ObjectID('D2AA'),
    // etc
  ]
}
```

非规范化后：

```js
db.products.findOne()
{
  name: 'left-handed smokeshifter',
  manufacturer: 'Acme Corp',
  catalog_number: 1234,
  parts: [
    { id: ObjectID('AAAA'), name: '#4 grommet' }, // Part name is denormalized
    { id: ObjectID('F17C'), name: 'fan blade assembly' },
    { id: ObjectID('D2AA'), name: 'power switch' },
    // etc
  ]
}
```

这样可以直接获取部件名称而无需联接，但如果需要部件的其他字段仍需查询 `parts` 集合。代价是更新更复杂：当部件名称变更时，必须更新每个出现该非规范化字段的产品文档。非规范化适用于读取远多于更新的字段。

注意：非规范化会使对该字段的原子、独立更新变得不可能；在更新流程中可能出现短暂的数据不一致（亚秒级）。

### 非规范化示例：从一端到多端

也可以将产品的一些字段（如产品名称或目录号）非规范化到零件文档中：

```js
db.parts.findOne()
{
  _id: ObjectID('AAAA'),
  partno: '123-aff-456',
  name: '#4 grommet',
  product_name: 'left-handed smokeshifter', // Denormalized from Product document
  product_catalog_number: 1234,              // Ditto
  qty: 94,
  cost: 0.94,
  price: 3.99
}
```

代价：当产品名称更新时，可能需要更新多个零件文档，因此更新成本可能更高。再次强调：是否采用此类非规范化取决于读写比率。

### 非规范化示例：一对一（将“一”侧信息放入“多”侧或将“多”侧摘要放入“一”侧）

将主机的 IP 地址非规范化到日志消息中：

```js
db.logmsg.findOne()
{
  time: ISODate("2014-03-28T09:42:41.382Z"),
  message: 'cpu is on fire!',
  ipaddr: '127.66.66.66',
  host: ObjectID('AAAB')
}
```

现在可以通过单一查询获取某 IP 的消息：

```js
last_5k_msg = db.logmsg.find({ ipaddr: '127.66.66.66' }).sort({ time: -1 }).limit(5000).toArray();
```

如果只需在“一”侧存储有限信息，也可以把这些信息全部非规范化到日志消息中，甚至完全舍弃 hosts 集合：

```js
db.logmsg.findOne()
{
  time: ISODate("2014-03-28T09:42:41.382Z"),
  message: 'cpu is on fire!',
  ipaddr: '127.66.66.66',
  hostname: 'goofy.example.com'
}
```

反向地，也可将“多”侧的摘要信息非规范化到“一”侧。例如，要在 host 文档中保留来自某主机的最后 1000 条消息，可以在插入日志时同时更新 `hosts` 文档中保留的有序数组（使用 $each / $slice 保持排序并限制长度）：

```js
// Get log message from monitoring system
logmsg = get_log_msg();
log_message_here = logmsg.msg;
log_ip = logmsg.ipaddr;
now = new Date();

// Find the _id for the host I'm updating (projection to _id only)
host_doc = db.hosts.findOne({ ipaddr: log_ip }, { _id: 1 });
host_id = host_doc._id;

// Insert the log message, the parent reference, and the denormalized data into the 'many'
db.logmsg.save({ time: now, message: log_message_here, ipaddr: log_ip, host: host_id });

// Push the denormalized log message onto the 'one' side
db.hosts.update(
  { _id: host_id },
  {
    $push: {
      logmsgs: {
        $each: [{ time: now, message: log_message_here }],
        $sort: { time: 1 },  // Keep sorted
        $slice: -1000        // Only retain latest 1000
      }
    }
  }
);
```

使用投影规范（{ _id: 1 }）可以防止 MongoDB 通过网络传输整个 hosts 文档，从而减少网络开销。

像所有非规范化设计一样，需考虑读写比率：只有当读取非规范化数据的频率远高于更新频率时，此类非规范化才有意义。

## 中级回顾：非规范化与双向引用的选择

- 如果双向引用能够优化数据访问，并且您能接受无法通过单一原子更新保证一致性，则可以使用双向引用。
- 如果使用引用，可以将数据从“一”侧非规范化到“N”侧，或从“N”侧非规范化到“一”侧，以减少联接。
- 非规范化使读取更快但写入更复杂且不原子，因此只在读写比率高且可以容忍最终一致性时采用。

数据库非规范化提供了大量选项：如果关系中有多个字段可选地进行非规范化，组合数会急剧增加，因此需要经验法则来引导决策。

## 非规范化的经验法则（您的彩虹指南）

1. 倾向于嵌入，除非有令人信服的理由不这样做。
2. 需要单独访问某个对象是不嵌入它的令人信服的理由。
3. 数组不应无限增长：如果“多”端有超过几百个文档，则不要嵌入；如果“多”端有超过几千个文档，请不要使用 ObjectID 引用数组。高基数数组就是不嵌入的一个理由。
4. 不要害怕应用程序级联接：如果正确索引并使用投影说明符，应用程序级联接几乎不会比关系数据库中的服务器端联接昂贵。
5. 考虑非规范化的读写比：大部分被读取且很少更新的字段是非规范化的良好候选者。频繁更新的字段不应非规范化，否则更新所有冗余数据实例的额外工作可能抵消收益。
6. 如何建模数据完全取决于应用程序的数据访问模式。应构建数据以匹配应用程序查询和更新数据的方式。

## 总结：主要决策点与建议

在 MongoDB 中建模“一对多”关系时需考虑：
- 关系的基数：是一对几、一对多还是 one-to-squillions？
- 是否需要单独访问 N 侧对象？
- 特定字段的更新与读取之比是多少？

主要建模选择：
- 对于一对少量（one-to-few），使用嵌入文档。
- 对于一对多或 N 侧需要独立访问，使用引用数组（或在需要时使用父引用以优化访问）。
- 对于 one-to-squillions，使用 parent-reference 存储在 N 侧文档中。

在确定总体结构后，可选择性地进行非规范化（将数据从一侧非规范化到多侧或反之），但只应对那些读取频繁、更新很少且不需要强一致性的字段进行非规范化。

MongoDB 的文档模型使您能够设计符合应用程序访问模式的数据库，从而提高灵活性与性能。

---

## 附录一：什么是数据库非规范化？

非规范化的原则是：一起访问的数据应该存储在一起。非规范化通过复制字段或派生字段来提高读取和查询性能，例如：
- 避免频繁需要从另一个集合读取的大文档字段的重复查询，可以在目标集合的嵌入文档中维护这些字段的副本，减少 $lookup 或应用级联接。
- 对某些字段经常需要计算平均值，可以在独立集合中维护派生字段并随写入更新。

非规范化能提高读取性能，但要确保保持重复数据的一致性。尽管 MongoDB 支持多文档事务，但很多场景下非规范化模型仍是最合适的选择。

## 附录二：何时比规范化更有意义？

非规范化在读写比率高（读取远多于写入）时有意义。通过非规范化可以避免昂贵的联接，但代价是更复杂、更昂贵的更新。一般建议：
- 仅对最常读取且很少更新的字段进行非规范化。
- 如果经常使用 $lookup 操作，考虑通过非规范化重组架构，以便查询单个集合获取所有需要的信息。

规范化模型（使用文档之间的引用）适用于：
- 嵌入会导致大量数据重复但无法提供足够读取性能优势时。
- 表示更复杂的多对多关系。
- 对大型分层数据集建模。

总体上，采用非规范化可以在单个操作中读取或写入整个记录时获得效率优势，但需权衡存储成本与更新复杂性。

---