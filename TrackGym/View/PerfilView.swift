//
//  PerfilView.swift
//  TrackGym
//
//  Created by Sergio Comerón on 22/8/25.
//
import SwiftUI
import SwiftData

struct PerfilView: View {
    @Environment(\.modelContext) private var context
    @Query private var perfiles: [Perfil]
    
    @State private var edad: Int = 18
    @State private var peso: Double = 70
    @State private var altura: Double = 170
    @State private var sexo: String = "Masculino"
    @State private var objetivo: String = "Ganar músculo"
    @State private var pecho: Double = 90
    @State private var cintura: Double = 80
    @State private var cadera: Double = 95
    @State private var biceps: Double = 30
    @State private var grasaCorporal: Double? = nil
    @State private var nivelActividad: String = "Moderada"
    @State private var restricciones: String = ""
    @State private var mostrandoAlerta = false

    private var perfilActual: Perfil? { perfiles.first }

    let sexos = ["Masculino", "Femenino", "Otro"]
    let objetivos = ["Ganar músculo", "Perder peso", "Mantener forma"]
    let niveles = ["Baja", "Moderada", "Alta"]

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Datos básicos")) {
                    Stepper(value: $edad, in: 12...100) {
                        Text("Edad: \(edad)")
                    }
                    HStack {
                        Text("Peso (kg)")
                        Spacer()
                        TextField("Peso", value: $peso, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Altura (cm)")
                        Spacer()
                        TextField("Altura", value: $altura, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                    }
                    Picker("Sexo", selection: $sexo) {
                        ForEach(sexos, id: \.self) { Text($0) }
                    }
                    Picker("Nivel de actividad", selection: $nivelActividad) {
                        ForEach(niveles, id: \.self) { Text($0) }
                    }
                }
                Section(header: Text("Objetivo")) {
                    Picker("Objetivo", selection: $objetivo) {
                        ForEach(objetivos, id: \.self) { Text($0) }
                    }
                }
                Section(header: Text("Medidas corporales (cm)")) {
                    HStack {
                        Text("Pecho")
                        Spacer()
                        TextField("Pecho", value: $pecho, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Cintura")
                        Spacer()
                        TextField("Cintura", value: $cintura, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Cadera")
                        Spacer()
                        TextField("Cadera", value: $cadera, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Bíceps")
                        Spacer()
                        TextField("Bíceps", value: $biceps, formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Grasa corporal (%)")
                        Spacer()
                        TextField("%", value: Binding(get: {
                            grasaCorporal ?? 0
                        }, set: { newValue in
                            grasaCorporal = newValue == 0 ? nil : newValue
                        }), formatter: NumberFormatter())
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                    }
                }
                Section(header: Text("Restricciones / notas")) {
                    TextField("Restricciones alimenticias, lesiones, etc.", text: $restricciones)
                }
                Button("Guardar perfil") {
                    guardarPerfil()
                    mostrandoAlerta = true
                }
            }
            .navigationTitle("Perfil")
            .alert("Perfil guardado", isPresented: $mostrandoAlerta) {
                Button("OK", role: .cancel) {}
            }
            .onAppear {
                cargarDatosPerfil()
            }
            .onChange(of: perfiles) { // Reacciona cuando cambian los datos en SwiftData
                cargarDatosPerfil()
            }
        }
    }
    
    // MARK: - Funciones privadas
    
    private func cargarDatosPerfil() {
        guard let perfil = perfilActual else { return }
        
        edad = perfil.edad
        peso = perfil.peso
        altura = perfil.altura
        sexo = perfil.sexo
        objetivo = perfil.objetivo
        pecho = perfil.pecho
        cintura = perfil.cintura
        cadera = perfil.cadera
        biceps = perfil.biceps
        grasaCorporal = perfil.grasaCorporal
        nivelActividad = perfil.nivelActividad
        restricciones = perfil.restricciones ?? ""
    }
    
    private func guardarPerfil() {
        if let perfil = perfilActual {
            // Actualizar perfil existente
            perfil.edad = edad
            perfil.peso = peso
            perfil.altura = altura
            perfil.sexo = sexo
            perfil.objetivo = objetivo
            perfil.pecho = pecho
            perfil.cintura = cintura
            perfil.cadera = cadera
            perfil.biceps = biceps
            perfil.grasaCorporal = grasaCorporal
            perfil.nivelActividad = nivelActividad
            perfil.restricciones = restricciones.isEmpty ? nil : restricciones
        } else {
            // Crear nuevo perfil
            let perfil = Perfil(
                edad: edad,
                peso: peso,
                altura: altura,
                sexo: sexo,
                objetivo: objetivo,
                pecho: pecho,
                cintura: cintura,
                cadera: cadera,
                biceps: biceps,
                grasaCorporal: grasaCorporal,
                nivelActividad: nivelActividad,
                restricciones: restricciones.isEmpty ? nil : restricciones
            )
            context.insert(perfil)
        }
        
        // Guardar cambios
        do {
            try context.save()
        } catch {
            print("Error al guardar el perfil: \(error)")
        }
    }
}

#Preview {
    PerfilView()
        .modelContainer(for: Perfil.self, inMemory: true)
}
