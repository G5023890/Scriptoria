import Foundation

enum SidebarSelection: Hashable {
    case collection(SmartCollection)
    case label(LabelID)
}
