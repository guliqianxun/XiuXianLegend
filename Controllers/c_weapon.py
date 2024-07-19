import ollama
import re

class ForgeController:
    def __init__(self, model, view):
        self.model = model
        self.view = view

        self.view.set_materials(self.model.materials)
        self.view.forge_button.clicked.connect(self.forge_weapon)

    def forge_weapon(self):
        material_name = self.view.material_combo_box.currentText()
        self.model.set_material(material_name)
        weapon = self.model.forge_weapon()
        if weapon:
            story, name = self.get_weapon_story_and_name(weapon.quality, material_name)
            weapon.name = name
            result_text = f"锻造成功！\n获得 {weapon.quality} 品质的 {weapon.name}！\n{story}"
        else:
            result_text = "锻造失败！"
        self.view.result_text.append(result_text)

    def get_weapon_story_and_name(self, quality, material):
        client = ollama.Client(host='http://localhost:11434')
        prompt = f"Generate a name and a short story for a {quality} weapon forged from {material}. in chinese and format as Name: name\nStory: story"
        response = client.chat(model='qwen2', messages=[
            {
                'role': 'user',
                'content': f'{prompt}',
            },
        ])

        if response['done']:
            content = response['message']['content']
            # 匹配名称
            name_pattern = re.compile(r'Name:\s*(.*?)\n')
            # 匹配故事
            story_pattern = re.compile(r'Story(.*?)$', re.S)

            name_match = name_pattern.search(content)
            story_match = story_pattern.search(content)

            name = name_match.group(1) if name_match else 'Name not found'
            story = story_match.group(1).strip() if story_match else content
            return story, name
        else:
            print(response)
            return "No story available.", "Unnamed"
