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

    @Query(sort: [SortDescriptor(\Entrenamiento.startDate, order: .reverse)])
    private var entrenamientos: [Entrenamiento]
    
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
            startDate: nil,
            endDate: nil
        )
        context.insert(nuevo)
        try? context.save()
        dismiss()
    }
}

