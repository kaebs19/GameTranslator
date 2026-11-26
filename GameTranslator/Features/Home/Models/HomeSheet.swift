/// What can open over the home screen. One at a time.
enum HomeSheet: String, Identifiable {
    case image, live, controls

    var id: String { rawValue }
}
