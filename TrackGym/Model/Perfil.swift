import SwiftUI
import SwiftData

@Model
class Perfil {
    var edad: Int = 0
    var peso: Double = 0
    var altura: Double = 0
    var sexo: String = "Masculino"
    var objetivo: String = "Perder peso"
    var pecho: Double = 0
    var cintura: Double = 0
    var cadera: Double = 0
    var biceps: Double = 0
    var grasaCorporal: Double? = nil // Opcional
    var nivelActividad: String = "Bajo"
    var restricciones: String? = nil

    init(edad: Int, peso: Double, altura: Double, sexo: String, objetivo: String, pecho: Double, cintura: Double, cadera: Double, biceps: Double, grasaCorporal: Double?, nivelActividad: String, restricciones: String?) {
        self.edad = edad
        self.peso = peso
        self.altura = altura
        self.sexo = sexo
        self.objetivo = objetivo
        self.pecho = pecho
        self.cintura = cintura
        self.cadera = cadera
        self.biceps = biceps
        self.grasaCorporal = grasaCorporal
        self.nivelActividad = nivelActividad
        self.restricciones = restricciones
    }
}

