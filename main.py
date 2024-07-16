import sys
from PySide6.QtWidgets import QApplication
from Controllers.c_weapon import ForgeController
from Models.weapon import ForgeModel
from Views.v_weapon import ForgeView


if __name__ == "__main__":
    app = QApplication(sys.argv)

    model = ForgeModel()
    view = ForgeView()
    controller = ForgeController(model, view)

    view.show()
    sys.exit(app.exec())
