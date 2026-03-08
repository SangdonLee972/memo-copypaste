package com.copynote.memo_copypaste

import android.database.sqlite.SQLiteDatabase
import android.inputmethodservice.InputMethodService
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputMethodManager
import android.widget.ImageButton
import android.widget.TextView
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import java.io.File

class MemoKeyboardService : InputMethodService() {

    private var snippets = mutableListOf<Triple<String, String, String>>() // id, title, content

    override fun onCreateInputView(): View {
        val view = LayoutInflater.from(this).inflate(R.layout.keyboard_view, null)

        loadSnippets()

        val recyclerView = view.findViewById<RecyclerView>(R.id.snippet_recycler)
        recyclerView.layoutManager = LinearLayoutManager(this)
        recyclerView.adapter = SnippetAdapter(snippets) { content ->
            currentInputConnection?.commitText(content, 1)
        }

        val backBtn = view.findViewById<ImageButton>(R.id.btn_back_keyboard)
        backBtn.setOnClickListener {
            val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
            imm.showInputMethodPicker()
        }

        return view
    }

    private fun loadSnippets() {
        snippets.clear()
        try {
            val dbPath = File(getDatabasePath("memo_copypaste.db").path)
            if (!dbPath.exists()) return
            val db = SQLiteDatabase.openDatabase(dbPath.path, null, SQLiteDatabase.OPEN_READONLY)
            val cursor = db.rawQuery(
                "SELECT id, title, content FROM snippets ORDER BY isPinned DESC, copyCount DESC LIMIT 50",
                null
            )
            while (cursor.moveToNext()) {
                snippets.add(
                    Triple(
                        cursor.getString(0) ?: "",
                        cursor.getString(1) ?: "",
                        cursor.getString(2) ?: ""
                    )
                )
            }
            cursor.close()
            db.close()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private class SnippetAdapter(
        private val items: List<Triple<String, String, String>>,
        private val onItemClick: (String) -> Unit
    ) : RecyclerView.Adapter<SnippetAdapter.ViewHolder>() {

        class ViewHolder(view: View) : RecyclerView.ViewHolder(view) {
            val title: TextView = view.findViewById(R.id.snippet_title)
            val content: TextView = view.findViewById(R.id.snippet_content)
        }

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): ViewHolder {
            val view = LayoutInflater.from(parent.context)
                .inflate(R.layout.keyboard_snippet_item, parent, false)
            return ViewHolder(view)
        }

        override fun onBindViewHolder(holder: ViewHolder, position: Int) {
            val (_, title, content) = items[position]
            holder.title.text = title.ifEmpty { content.take(30) }
            holder.content.text = content
            holder.itemView.setOnClickListener { onItemClick(content) }
        }

        override fun getItemCount() = items.size
    }
}
