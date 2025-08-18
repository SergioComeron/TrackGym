//
//  AddEntrenamientoView.swift
//  TrackGym
//
//  Created by Sergio Comerón on 17/8/25.
//

import SwiftUI
import SwiftData

struct AddEntrenamientoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section("Inicio") {
                    LabeledContent("Se registrará") {
                        Text("Fecha y hora actual al guardar")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Nuevo entrenamiento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                }
            }
        }
    }

    private func save() {
        let nuevo = Entrenamiento(
            id: UUID(),
            startDate: Date(),
            endDate: nil
        )
        context.insert(nuevo)
        try? context.save()
        // 🔹 Arrancar Live Activity aquí
        // 🔹 Arrancar Live Activity aquí
        Task {
            print("➡️ Intentando iniciar Live Activity...")
            await LiveActivityManager.shared.start(
                title: "Entrenamiento",
                startedAt: nuevo.startDate ?? Date(),
                entrenamientoID: nuevo.id
            )
            print("✅ Live Activity iniciada (si permisos y dispositivo lo permiten)")
        }
        dismiss()
    }
}
