import sys
import random

class Base():
    def __init__(self):
        self.life = randset(100,20)
        self.attack = randset(10,5)
        self.defense = randset(5,2)
        self.xiuwei = 0
        self.state_number = 0
        self.growing = randset(10,3)
        self.character_state = ['凡人境','融合期','金丹期','元婴期','分神期',
            '合体期','洞虚期','大乘期','飞升期']
            
def randset(medium,ranges):
    """一个随机函数，第一个参数为取值，第二个参数为随机范围（int型）"""
    ranges = abs(ranges)
    min_number = int(medium - ranges)
    if min_number < 0:
        min_number = 0
    max_number = int(medium + ranges)
    return random.randint(min_number,max_number)
    
class Attribute():
    
    def __init__(self):
        super().__init__()
        self.i_base = Base()


        
def run():
    character = Attribute()
    printinformation(character)
    while(1):
        exercise(character)
            
def printinformation(character):
    print("生命:",character.i_base.life)
    print("攻击:",character.i_base.attack)
    print("防御:",character.i_base.defense)
    print("修为:",character.i_base.xiuwei)
    print("境界:",
        character.i_base.character_state[character.i_base.state_number])  
        
def exercise(character):
    """修炼函数，完成修炼功能"""
    sign = input("如果退出请输入:quit\n")
    if sign == "quit":
        exit()
    else:
        character.i_base.xiuwei += character.i_base.growing
        printinformation(character)
            
        
run()
