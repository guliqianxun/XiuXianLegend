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
            result_text = f"锻造成功！\n获得 {weapon.quality} 品质的 {weapon.name}！"
        else:
            result_text = "锻造失败！"
        self.view.result_text.append(result_text)
