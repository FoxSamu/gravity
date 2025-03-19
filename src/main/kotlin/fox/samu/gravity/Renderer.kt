package fox.samu.gravity

import org.joml.Matrix3f
import org.joml.Vector3f
import org.lwjgl.opengl.GL33.*
import java.io.InputStreamReader
import kotlin.math.min
import kotlin.math.sin

class Renderer : Scope {
    private var vao = 0
    private var vbo = 0

    private var prog = 0
    private val shaders = mutableListOf<Int>()

    private var uniformScreenSize = 0
    private var uniformAspect = 0
    private var uniformSkymap = 0
    private var uniformDustmap = 0
    private var uniformTime = 0

    private var uniformCameraPos = 0
    private var uniformCameraDir = 0

    private val skymapTex = Texture("skymap.png")
    private val dustTex = Texture("dust.png")

    private val refTime = System.currentTimeMillis()

    private val camPos = Vector3f()
    private val camDir = Matrix3f()

    private val camDirArray = FloatArray(9)

    override fun init() {
        vao = glGenVertexArrays()
        vbo = glGenBuffers()

        prog = glCreateProgram()
        glAttachShader(prog, loadShader("vsh.glsl", GL_VERTEX_SHADER))
        glAttachShader(prog, loadShader("fsh.glsl", GL_FRAGMENT_SHADER))

        glLinkProgram(prog)
        if (glGetProgrami(prog, GL_LINK_STATUS) == GL_FALSE) {
            val log = glGetProgramInfoLog(prog)

            throw RuntimeException("Failed to link shader program:${System.lineSeparator()}$log")
        }

        uniformScreenSize = glGetUniformLocation(prog, "screenSize")
        uniformAspect = glGetUniformLocation(prog, "aspect")
        uniformSkymap = glGetUniformLocation(prog, "skymap")
        uniformDustmap = glGetUniformLocation(prog, "dustmap")
        uniformTime = glGetUniformLocation(prog, "time")
        uniformCameraPos = glGetUniformLocation(prog, "cameraPos")
        uniformCameraDir = glGetUniformLocation(prog, "cameraDir")

        val geom = floatArrayOf(
            -1f, -1f, 0f,
            1f, -1f, 0f,
            1f, 1f, 0f,

            -1f, -1f, 0f,
            1f, 1f, 0f,
            -1f, 1f, 0f
        )

        glBindVertexArray(vao)
        glBindBuffer(GL_ARRAY_BUFFER, vbo)

        glBufferData(GL_ARRAY_BUFFER, geom, GL_STATIC_DRAW)

        glEnableVertexAttribArray(0)
        glVertexAttribPointer(0, 3, GL_FLOAT, false, 3*4, 0L)

        glBindBuffer(GL_ARRAY_BUFFER, 0)
        glBindVertexArray(0)

        skymapTex.init()
        dustTex.init()
    }

    fun render(width: Int, height: Int) {
        val time = System.currentTimeMillis() - refTime
        val timeF = time / 1000f

        camPos
            .set(0f, 0f, 35f + min(500f, 500f/(timeF * timeF * 3)) + (sin(timeF / 10f) * 10f + 5f))
        camDir
            .identity()
            .rotateY(timeF / 4f)
            .rotateX(sin(timeF / (19f / 10f * 4f)) / 4f)

        camPos.mul(camDir)

        camDir.get(camDirArray)

        glViewport(0, 0, width, height)
        glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)

        glDisable(GL_CULL_FACE)

        glBindVertexArray(vao)
        glBindBuffer(GL_ARRAY_BUFFER, vbo)
        glUseProgram(prog)
        skymapTex.bind(0)
        dustTex.bind(1)

        glUniform2f(uniformScreenSize, width.toFloat(), height.toFloat())
        glUniform2f(uniformAspect, width.toFloat() / height.toFloat(), 1f)
        glUniform1i(uniformSkymap, 0)
        glUniform1i(uniformDustmap, 1)
        glUniform1f(uniformTime, timeF)
        glUniform3f(uniformCameraPos, camPos.x, camPos.y, camPos.z)
        glUniformMatrix3fv(uniformCameraDir, false, camDirArray)

        glDrawArrays(GL_TRIANGLES, 0, 6)

        dustTex.unbind(1)
        skymapTex.unbind(0)
        glUseProgram(0)
        glBindBuffer(GL_ARRAY_BUFFER, 0)
        glBindVertexArray(0)
    }

    override fun drop() {
        dustTex.drop()
        skymapTex.drop()

        for (shader in shaders) {
            glDeleteShader(shader)
        }

        if (prog != 0) glDeleteProgram(prog)
        if (vbo != 0) glDeleteBuffers(vbo)
        if (vao != 0) glDeleteVertexArrays(vao)
    }



    private fun loadResource(name: String): String {
        val input = this::class.java.getResourceAsStream("/$name")
            ?: throw RuntimeException("Failed to load resource '$name'")

        return InputStreamReader(input, Charsets.UTF_8).use {
            it.readText()
        }
    }

    private fun loadShader(name: String, type: Int): Int {
        val shader = glCreateShader(type)
        val source = loadResource(name)

        glShaderSource(shader, source)

        glCompileShader(shader)
        if (glGetShaderi(shader, GL_COMPILE_STATUS) == GL_FALSE) {
            val log = glGetShaderInfoLog(shader)

            glDeleteShader(shader)
            throw RuntimeException("Failed to compile shader '$name':${System.lineSeparator()}$log")
        }

        shaders += shader

        return shader
    }
}
