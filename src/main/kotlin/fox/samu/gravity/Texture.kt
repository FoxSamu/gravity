package fox.samu.gravity

import org.lwjgl.opengl.GL33.*
import org.lwjgl.stb.STBImage.*
import org.lwjgl.system.MemoryUtil.*

class Texture(val path: String) : Scope {
    var handle = 0
        private set

    override fun init() {
        handle = glGenTextures()

        val input = this.javaClass.getResourceAsStream("/$path")
            ?: throw RuntimeException("Could not find resource '$path'")

        val raw = input.use {
            it.readAllBytes()
        }

        val rawOffHeap = memAlloc(raw.size)

        try {
            rawOffHeap.put(raw).flip()

            val w = intArrayOf(0)
            val h = intArrayOf(0)
            val c = intArrayOf(0)

            val buf = stbi_load_from_memory(rawOffHeap, w, h, c, 4)
                ?: throw RuntimeException("Failed to load image '$path'")

            try {
                handle = glGenTextures()
                bind(0)
                glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w[0], h[0], 0, GL_RGBA, GL_UNSIGNED_BYTE, buf)

                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
                glGenerateMipmap(GL_TEXTURE_2D)
                unbind(0)
            } finally {
                stbi_image_free(buf)
            }
        } finally {
            memFree(rawOffHeap)
        }
    }

    fun bind(slot: Int) {
        glActiveTexture(GL_TEXTURE0 + slot)
        glBindTexture(GL_TEXTURE_2D, handle)
        checkError()
    }

    fun unbind(slot: Int) {
        glActiveTexture(GL_TEXTURE0 + slot)
        glBindTexture(GL_TEXTURE_2D, 0)
        checkError()
    }

    override fun drop() {
        if (handle != 0) glDeleteTextures(handle)
        handle = 0
    }

}
