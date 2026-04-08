"""
导出为 app asset 格式的 JSON 文件
按省份 + 考试类型 + 年份拆分，并生成 index.json
"""

import json
import os
import logging
from collections import defaultdict
from datetime import datetime

from data_cleaner import clean_records

logger = logging.getLogger(__name__)

# 省份 → 拼音映射（用于文件名）
PROVINCE_PINYIN = {
    '江苏': 'jiangsu',
    '浙江': 'zhejiang',
    '上海': 'shanghai',
    '山东': 'shandong',
    '北京': 'beijing',
    '广东': 'guangdong',
    '四川': 'sichuan',
    '湖北': 'hubei',
    '全国': 'quanguo',
}

# 考试类型 → 拼音映射
EXAM_TYPE_PINYIN = {
    '国考': 'guokao',
    '省考': 'shengkao',
    '事业编': 'shiyebian',
}

# 输出目录（相对于项目根目录）
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'data', 'exam_entry_scores')
ASSET_PREFIX = 'assets/data/exam_entry_scores'


def export_to_assets(records: list[dict], output_dir: str = OUTPUT_DIR) -> dict:
    """
    将数据导出为 asset JSON 文件

    Args:
        records: 原始数据记录列表
        output_dir: 输出目录
    Returns:
        index.json 内容（dict）
    """
    # 清洗数据
    cleaned = clean_records(records)
    if not cleaned:
        logger.warning('清洗后无有效数据')
        return {}

    # 按 省份+考试类型+年份 分组
    groups = defaultdict(list)
    for record in cleaned:
        # 国考按年份分组（不按省份），省考/事业编按省份+年份
        if record['exam_type'] == '国考':
            key = ('guokao', record['year'])
        else:
            province_py = PROVINCE_PINYIN.get(record['province'], record['province'])
            exam_py = EXAM_TYPE_PINYIN.get(record['exam_type'], record['exam_type'])
            key = (f'{province_py}_{exam_py}', record['year'])
        groups[key].append(record)

    # 确保输出目录存在
    os.makedirs(output_dir, exist_ok=True)

    # 写入各分组 JSON 文件
    files = []
    for (group_name, year), items in sorted(groups.items()):
        filename = f'{group_name}_{year}.json'
        filepath = os.path.join(output_dir, filename)
        asset_path = f'{ASSET_PREFIX}/{filename}'

        # 排序：省份 → 城市 → 部门 → 岗位名称
        items.sort(key=lambda x: (x['province'], x['city'], x['department'], x['position_name']))

        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(items, f, ensure_ascii=False, indent=2)

        files.append(asset_path)
        logger.info(f'已导出: {filename} ({len(items)} 条)')

    # 生成 index.json
    index = {
        'files': files,
        'version': '1.0.0',
        'updated_at': datetime.now().strftime('%Y-%m-%d'),
    }

    index_path = os.path.join(output_dir, 'index.json')
    with open(index_path, 'w', encoding='utf-8') as f:
        json.dump(index, f, ensure_ascii=False, indent=2)
    f.close()

    logger.info(f'index.json 已更新: {len(files)} 个数据文件')
    return index


def main():
    """
    主入口：调用各爬虫 → 清洗 → 导出

    用法：
        python export_json.py
        python export_json.py --province 山东 --year 2024
    """
    import argparse

    parser = argparse.ArgumentParser(description='爬取并导出进面分数线数据')
    parser.add_argument('--province', type=str, help='指定省份')
    parser.add_argument('--year', type=int, help='指定年份')
    parser.add_argument('--type', type=str, choices=['guokao', 'shengkao', 'shiyebian', 'all'],
                        default='all', help='爬取类型')
    parser.add_argument('--output', type=str, default=OUTPUT_DIR, help='输出目录')
    args = parser.parse_args()

    all_records = []

    if args.type in ('guokao', 'all'):
        from guokao_scraper import GuokaoScraper
        scraper = GuokaoScraper()
        data = scraper.scrape(year=args.year)
        all_records.extend(data)
        print(f'国考: {len(data)} 条')

    if args.type in ('shengkao', 'all'):
        from shengkao_scraper import ShengkaoScraper
        scraper = ShengkaoScraper()
        data = scraper.scrape(province=args.province, year=args.year)
        all_records.extend(data)
        print(f'省考: {len(data)} 条')

    if args.type in ('shiyebian', 'all'):
        from shiyebian_scraper import ShiyebianScraper
        scraper = ShiyebianScraper()
        data = scraper.scrape(province=args.province, year=args.year)
        all_records.extend(data)
        print(f'事业编: {len(data)} 条')

    if all_records:
        index = export_to_assets(all_records, args.output)
        print(f'\n导出完成: {len(index.get("files", []))} 个文件')
    else:
        print('未获取到任何数据')


if __name__ == '__main__':
    main()
