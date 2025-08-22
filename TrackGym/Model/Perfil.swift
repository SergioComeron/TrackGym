import SwiftUI
import SwiftData

@Model
class Perfil {
    var edad: Int
    var peso: Double
    var altura: Double
    var sexo: String
    var objetivo: String
    var pecho: Double
    var cintura: Double
    var cadera: Double
    var biceps: Double
    var grasaCorporal: Double? // Opcional
    var nivelActividad: String
    var restricciones: String?

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

