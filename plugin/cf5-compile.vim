" Copyright (c) 2014-2017 Vahagn Khachatryan (https://github.com/vishap)
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
" 
" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.
" 
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.
" 
" Name:         cf5-compile.vim
" Version:      1.0.1
" Authors:      Vahagn Khachatryan <vahagn DOT khachatryan AT gmail DOT com>
"
" Licence:      http://www.opensource.org/licenses/mit-license.php
"               The MIT License
"
" Summary:      Vim plugin to compile the edited files and run it.
"
" Description:
"               Functions to compile/link and run a single c/cpp/java/..etc
"               file based programs. It's irreplaceable for small tests or 
"               experiments.
"
"               How To Use
"               --------------
"               1 ) Put this file into vim plugin directory. For linux users
"                   should be $HOME/.vim/plugin.
"                   NOTE: feel free to add the plugin with Vundle if you use one.
"                         Plugin 'vishap/cf5-compile'
"
"               2 ) In your .vimrc file add
"
"                   map <silent> <C-F5> :call CF5Compile(1)<CR>
"                   map <silent> <F5> :call CF5Compile(0)<CR>
"
"                   This will allow Ctrl-F5 to "compile and run" and F5 to only
"                   "compile" the file. Please, note that "filetype" is used to
"                   define the compiler/interpreter used.
"
"               The value of the following variables are used while compiling
"               a file:
"                   b:argv - command line arguments to pass to program.
"                   b:flags - flags to pass to interpreter.
"                   b:cppflags - flags to pass to c++ compiler.
"                   b:wcppflags - flags to pass to (windows) compiler.
"                   b:lcppflags - flags to pass to (linux) compiler.
"                   b:ldflags - flags to pass to linker.
"                   b:ldlibpath - paths to add to PATH or LD_LIBRARY_PATH.
"
"               I personally use this script with let-modeline.vim. The last
"               allows to define some of compiler options right in the file. For
"               example I have the following header in some of my cpp files:
"               /*
"               VIM: let b:lcppflags="-std=c++11 -O2 -pthread"
"               VIM: let b:wcppflags="/O2 /EHsc /DWIN32"
"               VIM: let b:cppflags=b:Iboost.b:Itbb
"               VIM: let b:ldflags=b:Lboost.b:Ltbb.b:tbbmalloc.b:tbbmproxy
"               VIM: let b:ldlibpath=b:Bboost.b:Btbb
"               VIM: let b:argv=""
"               */
"
"               You might also consider using independence.vim or localvimrc.vim
"               in order to configure the plugin for a particular directory.
"
"               Enjoy.
"
if exists('g:loaded_cf5_compiler')
   finish
endif
let g:loaded_cf5_compiler = 1

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"   Compiling/interpretting {{{1
"


"
"   Microsoft Visual C++
"
function! s:CompileMSVC(run) "{{{2
    let exename=expand("%:p:r:s,$,.exe,")
    let srcname=expand("%")
    " compile it
    let ccline="cl ".b:cppflags." ".b:wcppflags." ".srcname." /Fe".exename." /link ".b:ldflags. " ".b:wldflags
    echo ccline
    let cout = system( ccline )
    if v:shell_error 
        echo cout
        return 
    endif
    echo cout
    " run it
    if a:run==1
        let en = "set PATH=\"".b:ldlibpath."%PATH%\""
        let cmdline=exename." ".b:argv
        let cont = [ en, cmdline ]
        let tf = tempname()
        let tf = fnamemodify( tf, ":p:r")
        let tf = tf.".bat"
        call writefile( cont, tf )

        let eout = system( tf )
        echo eout

        call delete( tf )
    endif
endfunction

"
"   GCC
"
function! s:CompileGCC(run) "{{{2
    let exename=expand("%:p:r:s,$,.exe,")
    let srcname=expand("%")
    " compile it
    let ccline="g++ ".b:cppflags." ".b:lcppflags." ".srcname." ".b:ldflags." -o".exename
    call s:appendOutput(ccline)
    let cout = system( ccline )
    if v:shell_error
        call s:appendOutput(cout)
        return 
    endif
    call s:appendOutput(cout)
    " run it
    if a:run == 1
        let $LD_LIBRARY_PATH="LD_LIBRARY_PATH=".b:ldlibpath.":".$LD_LIBRARY_PATH
        let cmdline=exename." ".b:argv
        call s:appendOutput(cmdline)
        let eout = system( cmdline )
        call s:appendOutput(eout)
    endif
endfunction

function! s:CompileJava(run) "{{{2
    " compile it
    let cmd = "javac " . b:javaflags . " " . expand("%")
    echo cmd
    let cout = system( cmd )
    echo cout
    if v:shell_error
        return 
    endif
    " run it
    "let classpath=expand("%:p:r")
    let exename=expand("%:r")
    let cmd = "java " . exename . " " . b:argv
    echo cmd
    let eout = system( cmd )
    echo eout
endfunction

function! s:InterpretPython(run)
    " Interpret it
    let cmd = "python " . b:flags . " " . expand("%") . ' ' . b:argv
    echo cmd
    let cout = system( cmd )
    echo cout
    if v:shell_error
        return 
    endif
endfunction

function! s:InterpretMatlab(run)
    " Interpret it
    let cmd = "octave " . b:flags . " " . expand("%") . ' ' . b:argv
    echo cmd
    let cout = system( cmd )
    echo cout
    if v:shell_error
        return 
    endif
endfunction

function! s:Compile(run)
    if &filetype=="c" || &filetype=="cpp"
        if has("win32") || has("win64")
            call s:CompileMSVC(a:run)
        else
            call s:CompileGCC(a:run)
        endif
    endif
    if &filetype=="python"
        call s:InterpretPython(a:run)
    endif
    if &filetype=="java"
        call s:CompileJava(a:run)
    endif
    if &filetype=="matlab"
        call s:InterpretMatlab(a:run)
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"   Output Window. {{{1
"
"
" This is an experimental option.
"       =0 - no output window opened.
"       =1 - output window opened.
"
let g:cf5output=0
"
"   Create output window.
"
function! s:getOutputWindow()
    if !exists("w:outputwin")
        let w:outputwin=tempname().'_output'
    endif
    let obuff = w:outputwin

    let winnr = bufwinnr('^'.obuff.'$')

    if (winnr < 0)
        execute "below 10new ".obuff
        setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile nowrap 
 "      setlocal nomodifiable
        let winnr = bufwinnr('^'.obuff.'$')
    endif

    return winnr
endfunction
"
"   Append text to output window.
"
function! s:appendOutput( text )
    if exists("g:cf5output") && (g:cf5output==1)
        let cwinnr = winnr()
        let owinnr = s:getOutputWindow()
"       setlocal modifiable
        execute owinnr . 'wincmd w'
        execute 'normal! Go'.a:text
"       setlocal nomodifiable
        execute cwinnr.'wincmd w'
    else
        echo a:text
    endif
endfunction
"
"   Clear text from output window.
"
function! s:clearOutputWindow()
    if exists("g:cf5output") && (g:cf5output==1)
        let cwinnr = winnr()
        let owinnr = s:getOutputWindow()
"       setlocal modifiable
        execute owinnr . 'wincmd w'
        execute 'normal ggdG'
"       setlocal nomodifiable
        execute cwinnr . 'wincmd w'
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"   Public interface. {{{1
"

"
"   Init global variables with default values.
"
function CF5CompileInitBufferVariables()
    let b:argv=""
    let b:flags=""
    let b:cppflags=""
    let b:wcppflags="/O2 /EHsc /DWIN32"
    let b:lcppflags="-O2"
    let b:ldflags=""
    let b:wldflags=""
    let b:ldlibpath=""
endfunction
autocmd BufNewFile,BufReadPre * :call CF5CompileInitBufferVariables()
"
"   Load compile instructions and call window or linux compiler. {{{1
"
function! CF5Compile(run)
    "
    "   Interpreters and compilers don't work with buffers, but ratter they run
    "   on files. So, make sure that the file is updated.
    "
    if &modified == 1
        echo "The buffer is not saved. First save it."
        return
    endif
    "
    "   If Set source specific compiler options.
    "   let-modeline.vim should be loaded for FirstModeLine.
    "
    if exists('*FirstModeLine')
        call FirstModeLine()
    endif
    "
    "   Clear output window
    "
    call s:clearOutputWindow()
    "
    "   Compile.
    "
    call s:Compile(a:run)
endfunction
"
"   Load compile instructions and call window or linux compiler.
"
function! CF5CompileAndRun()
    call CF5Compile(1)
endfunction
"
"   Load compile instructions and call window or linux compiler.
"
function! CF5CompileOnly()
    call CF5Compile(0)
endfunction

