package fox.samu.gravity

import org.lwjgl.glfw.GLFW.*
import org.lwjgl.opengl.GL

class Window : Scope {
    private var window: Long = 0L

    private val w = intArrayOf(0)
    private val h = intArrayOf(0)

    override fun init() {
        if (!glfwInit()) {
            throw RuntimeException("GLFW was not initialised")
        }

        glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3)
        glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3)
        glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE)

        window = glfwCreateWindow(960, 540, "CG", 0L, 0L)

        if (window == 0L) {
            throw RuntimeException("Window was not created")
        }

        glfwShowWindow(window)
        glfwMakeContextCurrent(window)

        GL.createCapabilities()

        glfwSwapInterval(1)
    }

    fun shouldClose(): Boolean {
        return glfwWindowShouldClose(window)
    }

    fun width(): Int {
        return w[0]
    }

    fun height(): Int {
        return h[0]
    }

    fun aspectRatio(): Float {
        return w[0].toFloat() / h[0].toFloat()
    }

    fun beginFrame() {
        glfwGetFramebufferSize(window, w, h)
    }

    fun endFrame() {
        glfwSwapBuffers(window)
        glfwPollEvents()
    }

    override fun drop() {
        if (window != 0L) {
            glfwDestroyWindow(window)
        }
        glfwTerminate()
    }
}
