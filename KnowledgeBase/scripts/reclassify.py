#!/usr/bin/env python3
import json
import re
from pathlib import Path
from typing import Dict, List, Tuple


def load_kb_structure() -> Dict:
    """載入知識庫分類結構"""
    with open('kb.json', 'r', encoding='utf-8') as f:
        return json.load(f)


def load_content() -> List[Tuple[str, str, str]]:
    """載入 output_with_md5.txt 的內容"""
    content = []
    with open('output_with_md5.txt', 'r', encoding='utf-8') as f:
        lines = f.read().splitlines()
    
    i = 0
    while i < len(lines):
        if i + 3 < len(lines) and lines[i+3].strip() == '----':
            title = lines[i].strip()
            url = lines[i+1].strip()
            md5 = lines[i+2].strip()
            if title and url and md5:
                content.append((title, url, md5))
            i += 4
        else:
            i += 1
    
    return content


def classify_content(content: List[Tuple[str, str, str]]) -> Dict:
    """根據內容標題和URL進行分類"""
    categories = {
        "基礎知識": {
            "資料庫概念": [],
            "關鍵術語與原理": [],
            "分散式資料庫概論": []
        },
        "系統架構": {
            "分散式系統設計": [],
            "架構模式與設計原則": [],
            "容器化與微服務": [],
            "雲端架構與部署": []
        },
        "資料庫管理": {
            "安裝部署與配置": [],
            "維運管理與日常作業": [],
            "備援與高可用性": [],
            "監控與日誌": []
        },
        "部署與維運 (DevOps/運維)": {
            "基礎設施自動化 (IaC)": [],
            "部署流程與 CI/CD": [],
            "設定管理與版本控制": []
        },
        "性能優化": {
            "查詢優化": [],
            "索引設計": [],
            "資源與緩存管理": [],
            "性能分析工具": []
        },
        "安全與合規": {
            "認證與授權": [],
            "資料加密與傳輸安全": [],
            "審計與合規": []
        },
        "災難復原與備份": {
            "備份策略": [],
            "恢復演練": [],
            "跨區域備援": []
        },
        "開發者支援": {
            "API 與 SDK": [],
            "資料模型與 Schema 設計": [],
            "測試與模擬 (Load/Chaos)": []
        },
        "工具與整合": {
            "監控工具": [],
            "可視化工具": [],
            "運維工具與自動化腳本": []
        },
        "培訓與文件": {
            "課程與認證活動": [],
            "操作手冊與教學文件": [],
            "FAQ 與Troubleshooting": []
        },
        "案例研究與實務": {
            "實作案例": [],
            "遷移與整合案例": [],
            "效能調校案例": []
        },
        "參考資源": {
            "論文與白皮書": [],
            "開源專案與範例": [],
            "社群與論壇": []
        }
    }
    
    # 關鍵字分類規則
    keywords = {
        "基礎知識": {
            "資料庫概念": ["資料庫", "database", "概念", "原理", "基礎"],
            "關鍵術語與原理": ["術語", "原理", "概念", "理論"],
            "分散式資料庫概論": ["TiDB", "分散式", "distributed", "分佈式"]
        },
        "系統架構": {
            "分散式系統設計": ["分散式", "分佈式", "distributed", "架構", "設計"],
            "架構模式與設計原則": ["架構", "設計", "模式", "原則"],
            "容器化與微服務": ["Docker", "容器", "微服務", "microservice", "Kubernetes"],
            "雲端架構與部署": ["雲端", "cloud", "部署", "AWS", "Azure", "GCP"]
        },
        "資料庫管理": {
            "安裝部署與配置": ["安裝", "部署", "配置", "setup", "install", "configure"],
            "維運管理與日常作業": ["維運", "管理", "日常", "運維", "operation"],
            "備援與高可用性": ["備援", "高可用", "HA", "replication", "cluster"],
            "監控與日誌": ["監控", "日誌", "monitor", "log", "告警"]
        },
        "部署與維運 (DevOps/運維)": {
            "基礎設施自動化 (IaC)": ["自動化", "IaC", "infrastructure", "terraform"],
            "部署流程與 CI/CD": ["CI/CD", "部署", "pipeline", "jenkins"],
            "設定管理與版本控制": ["設定", "配置", "版本控制", "git"]
        },
        "性能優化": {
            "查詢優化": ["查詢", "query", "優化", "optimization", "SQL"],
            "索引設計": ["索引", "index", "設計"],
            "資源與緩存管理": ["緩存", "cache", "記憶體", "memory", "資源"],
            "性能分析工具": ["性能", "performance", "分析", "工具", "profiler"]
        },
        "安全與合規": {
            "認證與授權": ["認證", "授權", "authentication", "authorization"],
            "資料加密與傳輸安全": ["加密", "安全", "security", "SSL", "TLS"],
            "審計與合規": ["審計", "合規", "audit", "compliance"]
        },
        "災難復原與備份": {
            "備份策略": ["備份", "backup", "策略"],
            "恢復演練": ["恢復", "recovery", "演練"],
            "跨區域備援": ["跨區域", "備援", "disaster recovery"]
        },
        "開發者支援": {
            "API 與 SDK": ["API", "SDK", "開發", "開發者"],
            "資料模型與 Schema 設計": ["資料模型", "schema", "設計"],
            "測試與模擬 (Load/Chaos)": ["測試", "模擬", "load test", "chaos"]
        },
        "工具與整合": {
            "監控工具": ["監控", "工具", "monitor", "tool"],
            "可視化工具": ["可視化", "visualization", "圖表"],
            "運維工具與自動化腳本": ["運維", "工具", "腳本", "script"]
        },
        "培訓與文件": {
            "課程與認證活動": ["培訓", "認證", "課程", "training", "certification"],
            "操作手冊與教學文件": ["手冊", "教學", "文件", "manual", "tutorial"],
            "FAQ 與Troubleshooting": ["FAQ", "故障排除", "troubleshooting", "問題"]
        },
        "案例研究與實務": {
            "實作案例": ["案例", "實作", "case study", "實例"],
            "遷移與整合案例": ["遷移", "整合", "migration", "integration"],
            "效能調校案例": ["效能", "調校", "tuning", "optimization"]
        },
        "參考資源": {
            "論文與白皮書": ["論文", "白皮書", "paper", "whitepaper"],
            "開源專案與範例": ["開源", "專案", "open source", "project"],
            "社群與論壇": ["社群", "論壇", "community", "forum"]
        }
    }
    
    # 分類邏輯
    for title, url, md5 in content:
        title_lower = title.lower()
        url_lower = url.lower()
        
        # 特殊規則：根據來源網站分類
        if "juejin.cn" in url:
            categories["開發者支援"]["資料模型與 Schema 設計"].append([title, f"collector/{md5}.pdf"])
            continue
        elif "mp.weixin.qq.com" in url:
            categories["培訓與文件"]["操作手冊與教學文件"].append([title, f"collector/{md5}.pdf"])
            continue
        elif "percona.com" in url:
            categories["資料庫管理"]["維運管理與日常作業"].append([title, f"collector/{md5}.pdf"])
            continue
        
        # 根據關鍵字分類
        classified = False
        for main_cat, sub_cats in keywords.items():
            for sub_cat, kw_list in sub_cats.items():
                for keyword in kw_list:
                    if keyword.lower() in title_lower or keyword.lower() in url_lower:
                        categories[main_cat][sub_cat].append([title, f"collector/{md5}.pdf"])
                        classified = True
                        break
                if classified:
                    break
            if classified:
                break
        
        # 如果沒有分類到任何類別，放入參考資源
        if not classified:
            categories["參考資源"]["社群與論壇"].append([title, f"collector/{md5}.pdf"])
    
    return categories


def save_classified_content(categories: Dict):
    """儲存分類後的內容"""
    # 儲存為 JSON
    with open('knowledge_base.json', 'w', encoding='utf-8') as f:
        json.dump(categories, f, ensure_ascii=False, indent=4)
    
    # 儲存為 Markdown
    with open('knowledge_base.md', 'w', encoding='utf-8') as f:
        f.write("# 知識庫分類目錄\n\n")
        
        for main_cat, sub_cats in categories.items():
            f.write(f"## {main_cat}\n\n")
            
            for sub_cat, items in sub_cats.items():
                if items:
                    f.write(f"### {sub_cat}\n\n")
                    for title, filename in items:
                        f.write(f"- [{title}]({filename})\n")
                    f.write("\n")
    
    print("已生成 knowledge_base.json 和 knowledge_base.md")


def main():
    print("開始重新分類知識庫內容...")
    
    # 載入內容
    content = load_content()
    print(f"載入了 {len(content)} 個項目")
    
    # 分類內容
    categories = classify_content(content)
    
    # 統計分類結果
    total_items = 0
    for main_cat, sub_cats in categories.items():
        for sub_cat, items in sub_cats.items():
            total_items += len(items)
            if items:
                print(f"{main_cat} > {sub_cat}: {len(items)} 個項目")
    
    print(f"\n總共分類了 {total_items} 個項目")
    
    # 儲存結果
    save_classified_content(categories)
    print("分類完成！")


if __name__ == "__main__":
    main()
