package fox.samu.gravity

import java.util.Stack

interface Scope {
    fun init()
    fun drop()
}

inline fun <R> using(vararg scopes: Scope, action: () -> R) {
    val initedScopes = Stack<Scope>()

    try {
        for (scope in scopes) {
            initedScopes.push(scope)
            scope.init()
        }

        action()
    } finally {
        while (initedScopes.isNotEmpty()) {
            initedScopes.pop().drop()
        }
    }
}
