import SwiftUI

struct AuthFlowView: View {
    @State private var showLogin = true

    var body: some View {
        ZStack {
            if showLogin {
                LoginView(showRegister: Binding(
                    get: { !showLogin },
                    set: { showLogin = !$0 }
                ))
            } else {
                RegisterView(showRegister: Binding(
                    get: { !showLogin },
                    set: { showLogin = !$0 }
                ))
            }
        }
    }
}
