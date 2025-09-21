//
//  AdminPanelView.swift
//  WDWDaydreams
//
//  Created by Jonathan Mandl on 9/21/25.
//

// Views/AdminPanelView.swift
import SwiftUI
import FirebaseFunctions

struct AdminPanelView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var newUserEmail = ""
    @State private var newUserRole = "user"
    @State private var authorizedUsers: [AuthorizedUser] = []
    @State private var isLoading = false
    @State private var statusMessage = ""
    @State private var showSuccess = false
    
    private let functions = Functions.functions()
    
    var body: some View {
        NavigationView {
            List {
                // Current User Info
                Section("Current User") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Email:")
                                .fontWeight(.medium)
                            Text(authViewModel.currentUserEmail)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Role:")
                                .fontWeight(.medium)
                            Text(authViewModel.userRole.capitalized)
                                .foregroundColor(authViewModel.isAdmin ? DisneyColors.mickeyRed : DisneyColors.magicBlue)
                                .fontWeight(.semibold)
                        }
                        
                        if authViewModel.isAdmin {
                            Label("Admin Access", systemImage: "crown.fill")
                                .foregroundColor(DisneyColors.mainStreetGold)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Add New User (Admin Only)
                if authViewModel.isAdmin {
                    Section("Authorize New User") {
                        VStack(spacing: 12) {
                            TextField("Email address", text: $newUserEmail)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            
                            Picker("Role", selection: $newUserRole) {
                                Text("User").tag("user")
                                Text("Admin").tag("admin")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            Button(action: authorizeUser) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    Text("Authorize User")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(DisneyButtonStyle())
                            .disabled(newUserEmail.isEmpty || isLoading)
                        }
                    }
                }
                
                // Authorized Users List
                Section("Authorized Users") {
                    if authorizedUsers.isEmpty && !isLoading {
                        Text("No authorized users found")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(authorizedUsers) { user in
                            UserRowView(user: user, onDeauthorize: authViewModel.isAdmin ? { deauthorizeUser(user) } : nil)
                        }
                    }
                }
                
                // Admin Actions
                if authViewModel.isAdmin {
                    Section("Admin Actions") {
                        Button("Refresh User List") {
                            loadAuthorizedUsers()
                        }
                        .foregroundColor(DisneyColors.magicBlue)
                        
                        Button("Refresh My Permissions") {
                            authViewModel.refreshUserClaims()
                        }
                        .foregroundColor(DisneyColors.fantasyPurple)
                    }
                }
            }
            .navigationTitle("User Management")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadAuthorizedUsers()
            }
            .alert("Status", isPresented: $showSuccess) {
                Button("OK") { statusMessage = "" }
            } message: {
                Text(statusMessage)
            }
        }
    }
    
    private func authorizeUser() {
        guard !newUserEmail.isEmpty else { return }
        
        isLoading = true
        
        let authorizeFunction = functions.httpsCallable("authorizeUser")
        authorizeFunction.call([
            "email": newUserEmail.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
            "role": newUserRole
        ]) { result, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    statusMessage = "Error: \(error.localizedDescription)"
                    showSuccess = true
                } else {
                    statusMessage = "User \(newUserEmail) authorized successfully!"
                    showSuccess = true
                    newUserEmail = ""
                    newUserRole = "user"
                    
                    // Refresh the user list
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        loadAuthorizedUsers()
                    }
                }
            }
        }
    }
    
    private func deauthorizeUser(_ user: AuthorizedUser) {
        let deauthorizeFunction = functions.httpsCallable("deauthorizeUser")
        deauthorizeFunction.call(["userId": user.uid]) { result, error in
            DispatchQueue.main.async {
                if let error = error {
                    statusMessage = "Error deauthorizing user: \(error.localizedDescription)"
                    showSuccess = true
                } else {
                    statusMessage = "User \(user.email) deauthorized successfully"
                    showSuccess = true
                    loadAuthorizedUsers()
                }
            }
        }
    }
    
    private func loadAuthorizedUsers() {
        guard authViewModel.isAuthorized else { return }
        
        isLoading = true
        
        let listFunction = functions.httpsCallable("listAuthorizedUsers")
        listFunction.call() { result, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    print("Error loading users: \(error.localizedDescription)")
                    statusMessage = "Error loading users: \(error.localizedDescription)"
                    showSuccess = true
                } else if let data = result?.data as? [String: Any],
                          let users = data["users"] as? [[String: Any]] {
                    
                    authorizedUsers = users.compactMap { userData in
                        guard let uid = userData["uid"] as? String,
                              let email = userData["email"] as? String else {
                            return nil
                        }
                        
                        return AuthorizedUser(
                            uid: uid,
                            email: email,
                            role: userData["role"] as? String ?? "user",
                            authorizedAt: userData["authorizedAt"] as? String,
                            lastSignIn: userData["lastSignIn"] as? String
                        )
                    }
                }
            }
        }
    }
}

struct UserRowView: View {
    let user: AuthorizedUser
    let onDeauthorize: (() -> Void)?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.email)
                    .fontWeight(.medium)
                
                HStack {
                    Text(user.role.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(user.role == "admin" ? DisneyColors.mickeyRed.opacity(0.2) : DisneyColors.magicBlue.opacity(0.2))
                        .foregroundColor(user.role == "admin" ? DisneyColors.mickeyRed : DisneyColors.magicBlue)
                        .cornerRadius(4)
                    
                    if let lastSignIn = user.lastSignIn {
                        Text("Last active: \(formatDate(lastSignIn))")
