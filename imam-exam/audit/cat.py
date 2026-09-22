import sys
from dalil import *
for a in sys.argv[1:]:
    i=int(a); print(f"--- c{i} [{chunks[i]['book']}]\n{clean(chunks[i]['txt'])[:900]}\n")
