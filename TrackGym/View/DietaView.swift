import SwiftUI

struct DietaView: View {
    var body: some View {
        NavigationStack {
            Text("Aquí irá tu dieta")
                .navigationTitle("Dieta")
        }
    }
}

#Preview {
    DietaView()
}
