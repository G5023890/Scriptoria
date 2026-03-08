import SwiftUI

struct AttachmentsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView("Attachments", systemImage: "paperclip.circle")
    }
}
