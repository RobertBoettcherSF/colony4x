/* Heap growth and the no-exception printer for the Ada WebAssembly runtime.
   __gnat_grow is called with a page count (64 KiB pages). A zero argument
   asks for the current memory end and does not grow. Otherwise the memory
   grows by that many pages and the old size, in pages, is returned.
   A failed grow returns 0, which the runtime treats as "no more memory". */
unsigned __gnat_grow (unsigned pages)
{
  unsigned old = __builtin_wasm_memory_size (0);
  if (pages != 0) {
    if (__builtin_wasm_memory_grow (0, pages) == (unsigned) -1)
      return 0;
  }
  return old;
}

void __gnat_put_exception (const void *msg, unsigned size, unsigned line)
{
  (void) msg;
  (void) size;
  (void) line;
}
