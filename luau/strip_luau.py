#!/usr/bin/env python3
"""Convert a Luau source file to Lua-5.4-compatible Lua by removing type
annotations and Luau-only syntax (compilable with luac for verification)."""
import re, sys

def strip(src):
    # remove --!strict / --!nonstrict
    src = re.sub(r'^--!.*$', '', src, flags=re.M)
    # anonymous function return-type annotations: `function(...): T` -> `function(...)`
    src = re.sub(r'(function\s*\((?:[^()]*)\))\s*:\s*[A-Za-z_][\w<>{}.,\[\] ?]*', r'\1', src)
    # `:: Type` casts inside table index: (p :: any)[k] -> p[k]
    src = re.sub(r'\(\s*(\w+)\s*::[^)]*\)', r'\1', src)
    src = re.sub(r'\s*::\s*[A-Za-z_][\w<>{}.,\[\] ?]*', '', src)
    # exported/local type declarations: `type Foo = ...` whole line
    src = re.sub(r'^\s*(export\s+)?type\s+\w+.*$', '', src, flags=re.M)
    # `local x: T = ...` and `local function f(...): T`
    src = re.sub(r'^(\s*local\s+\w+)\s*:\s*[^=\n]+=', r'\1 =', src, flags=re.M)
    src = re.sub(r'^(\s*local\s+function\s+[\w.]+\([^)]*\))\s*:\s*[^=\n]+', r'\1', src, flags=re.M)
    src = re.sub(r'^(\s*function\s+[\w.:]+\([^)]*\))\s*:\s*[^\n]+?(?=\s*(do|$))', r'\1', src, flags=re.M)
    # parameter annotations: split per top-level paren group is complex; handle simple lines:
    def strip_params(m):
        params = m.group(2)
        params = re.sub(r'\{[^{}]*\}', 'T', params)  # hide { T } types from the regex
        cleaned = re.sub(r'\b([A-Za-z_]\w*)\??\s*:\s*(?:\{[^{}]*\}|[^,()])+', r'\1', params)
        cleaned = cleaned.replace('?', '')
        return m.group(1) + cleaned + ')'
    src = re.sub(r'(function [\w.:]*\()([^()]*)\)', strip_params, src)
    # typed local var decl without initializer: `local studs: { BasePart }`
    src = re.sub(r'^(\s*local\s+\w+)\s*:\s*\{[^=\n]*\}\s*$', r'\1', src, flags=re.M)
    src = re.sub(r'^(\s*local\s+\w+)\s*:\s*[A-Za-z_][\w<>,.\[\] ?]*\s*$', r'\1', src, flags=re.M)
    # `for k, v in props do` stays fine. `continue` not used.
    # compound ops += -= *= /= already exist in Lua 5.4. OK.
    return src

if __name__ == "__main__":
    for f in sys.argv[1:]:
        out = f.rsplit('.', 1)[0] + '.lua'
        open(out, 'w').write(strip(open(f).read()))
        print("wrote", out)
