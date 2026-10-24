import SwiftData
import SwiftUI

struct CategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomCategory.name) private var categories: [CustomCategory]
    @Query private var transactions: [Transaction]
    @Query private var incomes: [Income]
    @Query private var fixedExpenses: [FixedExpense]

    @State private var editedCategory: CustomCategory?
    @State private var showsNewCategory = false
    @State private var categoryToDelete: CustomCategory?

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    Button {
                        editedCategory = category
                    } label: {
                        Label(category.name, systemImage: category.systemImage)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("common.delete", role: .destructive) {
                            categoryToDelete = category
                        }
                    }
                }
            } header: {
                Text("categories.custom.section")
            } footer: {
                Text("categories.custom.footer")
            }

            Section {
                Button {
                    showsNewCategory = true
                } label: {
                    Label("categories.add", systemImage: "plus")
                }
            }
        }
        .navigationTitle("categories.manage")
        .sheet(isPresented: $showsNewCategory) {
            CategoryEditorView(category: nil)
        }
        .sheet(item: $editedCategory) { category in
            CategoryEditorView(category: category)
        }
        .confirmationDialog(
            "categories.delete.title",
            isPresented: Binding(
                get: { categoryToDelete != nil },
                set: { if !$0 { categoryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("categories.delete.action", role: .destructive) {
                if let categoryToDelete { delete(categoryToDelete) }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("categories.delete.message")
        }
    }

    private func delete(_ category: CustomCategory) {
        for transaction in transactions where transaction.customCategoryName == category.name {
            transaction.customCategoryName = nil
            transaction.category = .other
        }
        for income in incomes where income.customCategoryName == category.name {
            income.customCategoryName = nil
            income.category = .other
        }
        for expense in fixedExpenses where expense.customCategoryName == category.name {
            expense.customCategoryName = nil
            expense.category = .other
        }
        modelContext.delete(category)
        try? modelContext.save()
        categoryToDelete = nil
    }
}

private struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]
    @Query private var incomes: [Income]
    @Query private var fixedExpenses: [FixedExpense]

    let category: CustomCategory?
    @State private var name: String
    @State private var systemImage: String

    private let icons = ["tag", "cart", "house", "car", "fork.knife", "heart", "pawprint", "airplane", "gift", "hammer"]

    init(category: CustomCategory?) {
        self.category = category
        _name = State(initialValue: category?.name ?? "")
        _systemImage = State(initialValue: category?.systemImage ?? "tag")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("categories.name", text: $name)
                Picker("categories.icon", selection: $systemImage) {
                    ForEach(icons, id: \.self) { icon in
                        Label(icon, systemImage: icon).tag(icon)
                    }
                }
            }
            .navigationTitle(category == nil ? "categories.add" : "categories.edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let category {
            let oldName = category.name
            category.name = trimmed
            category.systemImage = systemImage
            for item in transactions where item.customCategoryName == oldName { item.customCategoryName = trimmed }
            for item in incomes where item.customCategoryName == oldName { item.customCategoryName = trimmed }
            for item in fixedExpenses where item.customCategoryName == oldName { item.customCategoryName = trimmed }
        } else {
            modelContext.insert(CustomCategory(name: trimmed, systemImage: systemImage))
        }
        try? modelContext.save()
        dismiss()
    }
}
