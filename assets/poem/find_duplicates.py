import json

with open('chinese_poems.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

# 用诗句内容作为key，收集所有标题
content_map = {}

for poem in data:
    # 获取正文内容（使用第一个语言的正文）
    paragraphs = poem.get('paragraphs_cns', [])
    if not paragraphs:
        continue
    
    # 将正文内容合并为一个字符串作为key
    content_key = ''.join(paragraphs)
    
    if content_key not in content_map:
        content_map[content_key] = []
    
    content_map[content_key].append({
        'id': poem.get('id'),
        'title': poem.get('title_cns'),
        'author': poem.get('author_cns'),
        'dynasty': poem.get('dynasty_cns'),
        'grade': poem.get('grade')
    })

# 找出有重复内容的
duplicates = {k: v for k, v in content_map.items() if len(v) > 1}

print("=" * 80)
print("内容重复的诗词（相同内容不同标题）")
print("=" * 80)

total_duplicates = 0
for content, poems in sorted(duplicates.items(), key=lambda x: len(x[1]), reverse=True):
    print(f"\n【{len(poems)}首内容相同】")
    for p in poems:
        print(f"  ID: {p['id']}, 标题: {p['title']}, 作者: {p['author']}, 朝代: {p['dynasty']}, 年级: {p['grade']}")
    total_duplicates += len(poems) - 1

print(f"\n{'=' * 80}")
print(f"总计: {len(duplicates)} 组重复，涉及 {total_duplicates} 个多余条目")
print("=" * 80)
