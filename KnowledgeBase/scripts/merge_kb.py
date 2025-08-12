#!/usr/bin/env python3
import json
from pathlib import Path


def load_kb_md5():
    """載入 knowledge_base_md5.json"""
    with open('knowledge_base_md5.json', 'r', encoding='utf-8') as f:
        return json.load(f)


def load_kb_md():
    """載入現有的 knowledge_base.md"""
    if Path('knowledge_base.md').exists():
        with open('knowledge_base.md', 'r', encoding='utf-8') as f:
            return f.read()
    return "# 知識庫分類目錄\n\n"


def merge_content(kb_md5_data, existing_md):
    """合併內容到 Markdown 格式"""
    lines = existing_md.splitlines()
    
    # 新增來自 knowledge_base_md5.json 的內容
    for main_cat, sub_cats in kb_md5_data.items():
        # 檢查是否已存在該主分類
        cat_exists = any(line.strip() == f"## {main_cat}" for line in lines)
        
        if not cat_exists:
            # 新增主分類
            lines.append(f"## {main_cat}\n")
        
        for sub_cat, items in sub_cats.items():
            if not items:
                continue
                
            # 檢查是否已存在該子分類
            sub_cat_exists = False
            for i, line in enumerate(lines):
                if line.strip() == f"### {sub_cat}":
                    sub_cat_exists = True
                    # 找到該子分類的結束位置
                    j = i + 1
                    while j < len(lines) and not lines[j].strip().startswith('###') and not lines[j].strip().startswith('##'):
                        j += 1
                    # 在現有項目後新增新項目
                    for item in items:
                        if len(item) == 3:
                            title, url, md5 = item
                            lines.insert(j, f"- [{title}](collector/{md5}.pdf)")
                        elif len(item) == 1:
                            # 處理只有標題或只有URL的情況
                            if item[0].startswith('http'):
                                lines.insert(j, f"- [連結]({item[0]})")
                            else:
                                lines.insert(j, f"- {item[0]}")
                        j += 1
                    break
            
            if not sub_cat_exists:
                # 新增子分類和項目
                lines.append(f"### {sub_cat}\n")
                for item in items:
                    if len(item) == 3:
                        title, url, md5 = item
                        lines.append(f"- [{title}](collector/{md5}.pdf)")
                    elif len(item) == 1:
                        # 處理只有標題或只有URL的情況
                        if item[0].startswith('http'):
                            lines.append(f"- [連結]({item[0]})")
                        else:
                            lines.append(f"- {item[0]}")
                lines.append("")
    
    return '\n'.join(lines)


def main():
    print("開始合併 knowledge_base_md5.json 到 knowledge_base.md...")
    
    # 載入資料
    kb_md5_data = load_kb_md5()
    existing_md = load_kb_md()
    
    # 合併內容
    merged_content = merge_content(kb_md5_data, existing_md)
    
    # 儲存結果
    with open('knowledge_base.md', 'w', encoding='utf-8') as f:
        f.write(merged_content)
    
    # 統計
    total_items = 0
    for main_cat, sub_cats in kb_md5_data.items():
        for sub_cat, items in sub_cats.items():
            total_items += len(items)
    
    print(f"已合併 {total_items} 個項目到 knowledge_base.md")
    print("合併完成！")


if __name__ == "__main__":
    main()
