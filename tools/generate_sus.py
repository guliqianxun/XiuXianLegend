#!/usr/bin/env python3
"""一次性脚本：生成青龙宿 28 颗 SuData .tres 文件。
运行：python tools/generate_sus.py
"""
import os
import math

SU_NAMES = [
    "jiao", "kang", "di", "fang", "xin", "wei", "ji",
    "dou", "niu", "nv", "xu", "wei2", "shi", "bi",
    "kui", "lou", "wei3", "mao", "bi2", "zi", "shen",
    "jing", "gui", "liu", "xing", "zhang", "yi", "zhen",
]
SU_DISPLAY = ["角", "亢", "氐", "房", "心", "尾", "箕",
              "斗", "牛", "女", "虚", "危", "室", "壁",
              "奎", "娄", "胃", "昴", "毕", "觜", "参",
              "井", "鬼", "柳", "星", "张", "翼", "轸"]

SLOTS = ["sword", "talisman", "puppet_core",
         "elixir_furnace", "eating_vessel", "divination_plate"]

OUT_DIR = "godot/data/sus"
os.makedirs(OUT_DIR, exist_ok=True)


def position(i: int) -> tuple[float, float]:
    if i < 24:
        theta = 2 * math.pi * i / 24
        x = 0.5 + 0.4 * math.cos(theta)
        y = 0.5 + 0.35 * math.sin(theta)
    else:
        offsets = [(0.5, 0.35), (0.65, 0.5), (0.5, 0.65), (0.35, 0.5)]
        x, y = offsets[i - 24]
    return round(x, 3), round(y, 3)


def placement(i: int) -> tuple[str, int, int]:
    slot = SLOTS[i % 6]
    band = i // 6
    if band == 0:
        qmin, qmax = 0, 0
    elif band == 1:
        qmin, qmax = 1, 1
    elif band == 2:
        qmin, qmax = 2, 2
    elif band == 3:
        qmin, qmax = 3, 4
    else:
        qmin, qmax = 0, 4
    return slot, qmin, qmax


TPL = '''[gd_resource type="Resource" script_class="SuData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/su_data.gd" id="1_s"]

[resource]
script = ExtResource("1_s")
id = &"{name}"
display_name = "{disp}"
match_path = &"sword"
match_quality_min = {qmin}
match_quality_max = {qmax}
position_x = {x}
position_y = {y}
'''

for i, name in enumerate(SU_NAMES):
    slot, qmin, qmax = placement(i)
    x, y = position(i)
    content = TPL.format(name=name, disp=SU_DISPLAY[i],
                         qmin=qmin, qmax=qmax, x=x, y=y)
    path = os.path.join(OUT_DIR, f"{name}.tres")
    with open(path, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"wrote {path}: {SU_DISPLAY[i]} q[{qmin},{qmax}] @({x},{y})")

print(f"\nGenerated {len(SU_NAMES)} SuData .tres files in {OUT_DIR}")
