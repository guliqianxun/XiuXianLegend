import ollama
import re
quality = "优秀"
material = "玄铁"
client = ollama.Client(host='http://localhost:11434')
prompt = f"Generate a name and a short story for a {quality} weapon forged from {material}. in chinese and format Name: name\nStory: story"
response = client.chat(model='qwen2', messages=[
    {
        'role': 'user',
        'content': f'{prompt}',
    },
])

print(response)
if response['done']:
    content = response['message']['content']
    # Parsing the response to extract name and story

    # 匹配名称
    name_pattern = re.compile(r'Name:\s*(.*?)\n')
    # 匹配故事
    story_pattern = re.compile(r'Story(.*?)$', re.S)

    name_match = name_pattern.search(content)
    story_match = story_pattern.search(content)

    name = name_match.group(1) if name_match else 'Name not found'
    story = story_match.group(1).strip() if story_match else 'Story not found'
    print(story, name) 
else:
    print("No story available.", "Unnamed")