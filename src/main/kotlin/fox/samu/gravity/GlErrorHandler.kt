package fox.samu.gravity

import org.lwjgl.opengl.GL33.*

fun checkError() {
    val err = glGetError()

    if (err != GL_NO_ERROR) {
        throw RuntimeException("GL Error %X".format(err))
    }
}
