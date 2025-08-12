#!/usr/bin/env python3
import re
from pathlib import Path


def extract_pdf_references():
    """從 knowledge_base.md 中提取所有 PDF 引用"""
    with open('knowledge_base.md', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 提取所有 collector/xxx.pdf 格式的引用
    pattern = r'collector/([a-f0-9]{32})\.pdf'
    matches = re.findall(pattern, content)
    return set(matches)


def get_actual_pdfs():
    """獲取實際存在的 PDF 檔案"""
    pdf_dir = Path('collector')
    if not pdf_dir.exists():
        return set()
    
    actual_pdfs = set()
    for pdf_file in pdf_dir.glob('*.pdf'):
        # 提取檔案名（不含副檔名）
        pdf_name = pdf_file.stem
        actual_pdfs.add(pdf_name)
    
    return actual_pdfs


def main():
    print("檢查缺失的 PDF 檔案...")
    
    # 獲取知識庫中引用的 PDF
    referenced_pdfs = extract_pdf_references()
    print(f"知識庫中引用的 PDF 數量: {len(referenced_pdfs)}")
    
    # 獲取實際存在的 PDF
    actual_pdfs = get_actual_pdfs()
    print(f"實際存在的 PDF 數量: {len(actual_pdfs)}")
    
    # 找出缺失的 PDF
    missing_pdfs = referenced_pdfs - actual_pdfs
    print(f"缺失的 PDF 數量: {len(missing_pdfs)}")
    
    if missing_pdfs:
        print("\n缺失的 PDF 檔案:")
        for pdf in sorted(missing_pdfs):
            print(f"  {pdf}.pdf")
        
        # 將缺失的 PDF 列表保存到檔案
        with open('missing_pdfs.txt', 'w', encoding='utf-8') as f:
            for pdf in sorted(missing_pdfs):
                f.write(f"{pdf}.pdf\n")
        print(f"\n已將缺失的 PDF 列表保存到 missing_pdfs.txt")
    
    # 找出多餘的 PDF（存在但未引用）
    extra_pdfs = actual_pdfs - referenced_pdfs
    if extra_pdfs:
        print(f"\n多餘的 PDF 數量: {len(extra_pdfs)}")
        print("多餘的 PDF 檔案:")
        for pdf in sorted(extra_pdfs):
            print(f"  {pdf}.pdf")


if __name__ == "__main__":
    main()
