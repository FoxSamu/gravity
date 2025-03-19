package fox.samu.gravity

fun main() {
    val window = Window()
    val renderer = Renderer()

    using(window, renderer) {
        while (!window.shouldClose()) {
            window.beginFrame()
            renderer.render(window.width(), window.height())
            window.endFrame()
        }
    }
}
