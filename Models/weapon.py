import random

class Material:
    def __init__(self, name, success_rate):
        self.name = name
        self.success_rate = success_rate

class Weapon:
    def __init__(self, name, quality):
        self.name = name
        self.quality = quality

class ForgeModel:
    def __init__(self):
        self.materials = [
            Material("普通铁矿", 0.6),
            Material("精炼钢", 0.8),
            Material("神秘矿石", 0.9)
        ]
        self.current_material = None

    def set_material(self, material_name):
        for material in self.materials:
            if material.name == material_name:
                self.current_material = material
                return True
        return False

    def forge_weapon(self):
        if not self.current_material:
            return None
        
        success = random.random() < self.current_material.success_rate
        if success:
            quality = random.choice(["普通", "优秀", "稀有", "史诗", "传说"])
            return Weapon("锻造武器", quality)
        else:
            return None
