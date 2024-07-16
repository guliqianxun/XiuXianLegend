from PySide6.QtWidgets import QApplication, QMainWindow, QWidget, QTextEdit, QPushButton, QVBoxLayout, QHBoxLayout, QLabel, QComboBox

class ForgeView(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("武器锻造系统")
        self.setGeometry(100, 100, 400, 300)

        self.central_widget = QWidget()
        self.setCentralWidget(self.central_widget)

        # 材料选择部分
        self.material_label = QLabel("选择锻造材料:")
        self.material_combo_box = QComboBox()
        
        # 锻造按钮
        self.forge_button = QPushButton("锻造")
        
        # 结果显示部分
        self.result_text = QTextEdit()
        self.result_text.setReadOnly(True)

        layout = QVBoxLayout()
        layout.addWidget(self.material_label)
        layout.addWidget(self.material_combo_box)
        layout.addWidget(self.forge_button)
        layout.addWidget(self.result_text)

        self.central_widget.setLayout(layout)

    def set_materials(self, materials):
        self.material_combo_box.clear()
        for material in materials:
            self.material_combo_box.addItem(material.name)
