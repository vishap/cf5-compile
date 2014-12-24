" Copyright (c) 2014 Vahagn Khachatryan
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
" Name:			cf5-compile.vim
" Version:		1.0.0
" Authors:		Vahagn Khachatryan <vahagn DOT khachatryan AT gmail DOT com>
"
" Licence:      http://www.opensource.org/licenses/mit-license.php
"               The MIT License
"
" Summary:		Vim plugin to compile the edited files and run it.
"
" Description:
"				Functions to compile/link and run a single c/cpp/java/..etc
"				file based programs. It's irreplaceable for small tests or 
"				experiments.
"				
"				How To Use
"				--------------
"				Put this file into vim plugin directory. For linux users should
"				be  $HOME/.vim/plugin. 
"				In your .vimrc file add 
"
"				map <silent> <C-F5> :call CF5Compile(1)<CR>
"				map <silent> <F5> :call CF5Compile(0)<CR>
"
"				This will allow Ctrl-F5 to "compile and run" and F5 to only 
"				"compile" the file. Please, note that "filetype" is used to
"				define the compiler/interpreter used.
"
"				The value of the following variables are used while compiling
"				a file:
"					g:argv - command line arguments to pass to program.
"					g:pyflags - flags to pass to python interpreter.
"					g:cppflags - flags to pass to c++ compiler.
"					g:wcppflags - flags to pass to (windows) compiler.
"					g:lcppflags - flags to pass to (linux) compiler.
"					g:ldflags - flags to pass to linker.
"					g:ldlibpath - paths to add to PATH or LD_LIBRARY_PATH.
"
"				I personally use this script with let-modeline.vim. The last
"				allows to define some of compiler options right in the file. For 
"				example I have the following header in some of my cpp files:
"				/*
"				VIM: let g:lcppflags="-std=c++11 -O2 -pthread"
"				VIM: let g:wcppflags="/O2 /EHsc /DWIN32"
"				VIM: let g:cppflags=g:Iboost.g:Itbb
"				VIM: let g:ldflags=g:Lboost.g:Ltbb.g:tbbmalloc.g:tbbmproxy
"				VIM: let g:ldlibpath=g:Bboost.g:Btbb
"				VIM: let g:argv=""
"				*/
"
"				You might also consider using independence.vim or localvimrc.vim
"				in order to configure the plugin for a particular directory.
"
"				Enjoy.
"
if exists('g:loaded_cf5_compiler')
   finish
endif
let g:loaded_cf5_compiler = 1

"
"	Init global variables with default values.
"
let g:argv=""
let g:pyflags=""
let g:cppflags=""
let g:wcppflags="/O2 /EHsc /DWIN32"
let g:lcppflags="-O2"
let g:ldflags=""
let g:wldflags=""
let g:ldlibpath=""
"
" This is an experimental option.
"		=0 - no output window opened.
"		=1 - output window opened.
"
let g:cf5output=0

"
"	Microsoft Visual C++
"
function! s:CompileMSVC(run) "{{{2
	let exename=expand("%:p:r:s,$,.exe,")
	let srcname=expand("%")
	" compile it
	let ccline="cl ".g:cppflags." ".g:wcppflags." ".srcname." /Fe".exename." /link ".g:ldflags. " ".g:wldflags
	echo ccline
	let cout = system( ccline )
	if v:shell_error 
		echo cout
		return 
	endif
	echo cout
	" run it
	if a:run==1
		let en = "set PATH=\"".g:ldlibpath."%PATH%\""
		let cmdline=exename." ".g:argv
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
"	GCC
"
function! s:CompileGCC(run) "{{{2
	let exename=expand("%:p:r:s,$,.exe,")
	let srcname=expand("%")
	" compile it
	let ccline="g++ ".g:cppflags." ".g:lcppflags." ".g:ldflags." ".srcname." -o".exename
	call s:appendOutput(ccline)
	let cout = system( ccline )
	if v:shell_error 
		call s:appendOutput(cout)
		return 
	endif
	call s:appendOutput(cout)
	" run it
	if a:run == 1
		let $LD_LIBRARY_PATH="LD_LIBRARY_PATH=".g:ldlibpath.":".$LD_LIBRARY_PATH
		let cmdline=exename." ".g:argv
		call s:appendOutput(cmdline)
		let eout = system( cmdline )
		call s:appendOutput(eout)
	endif
endfunction

function! s:CompileJava(run) "{{{2
	" compile it
	let cmd = "javac " . g:javaflags . " " . expand("%")
	echo cmd
	let cout = system( cmd )
	echo cout
	if v:shell_error
		return 
	endif
	" run it
	"let classpath=expand("%:p:r")
	let exename=expand("%:r")
	let cmd = "java " . exename . " " . g:argv
	echo cmd
	let eout = system( cmd )
	echo eout
endfunction

function! s:InterpretPython(run)
	" Interpret it
	let cmd = "python " . g:pyflags . " " . expand("%") . ' ' . g:argv
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
endfunction

"
"	Output Window {{{1
"
"	Create output window. {{{2
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
 " 		setlocal nomodifiable
		let winnr = bufwinnr('^'.obuff.'$')
	endif

	return winnr
endfunction
"
"	Append text to output window. {{{2
"
function! s:appendOutput( text )
	if exists("g:cf5output") && (g:cf5output==1)
		let cwinnr = winnr()
		let owinnr = s:getOutputWindow()
"	 	setlocal modifiable
		execute owinnr . 'wincmd w'
		execute 'normal! Go'.a:text
"  		setlocal nomodifiable
		execute cwinnr.'wincmd w'
	else
		echo a:text
	endif
endfunction
"
"	Clear text from output window. {{{2
"
function! s:clearOutputWindow()
	if exists("g:cf5output") && (g:cf5output==1)
		let cwinnr = winnr()
		let owinnr = s:getOutputWindow()
"	 	setlocal modifiable
		execute owinnr . 'wincmd w'
		execute 'normal ggdG'
"	  	setlocal nomodifiable
		execute cwinnr . 'wincmd w'
	endif
endfunction
"
"	Load compile instructions and call window or linux compiler. {{{1
"
function! CF5Compile(run)
	"
	"	Interpreters and compilers don't work with buffers, but ratter they run
	"	on files. So, make sure that the file is updated.
	"
	if &modified == 1
		echo "The buffer is not saved. First save it."
		return
	endif
	"
	"	Set source specific compiler options.
	"	let-modeline.vim should be loaded for FirstModeLine.
	"
	if exists('*FirstModeLine')
		call FirstModeLine()
	endif
	"
	"	Clear output window
	"
	call s:clearOutputWindow()
	"
	"	Compile.
	"
	call s:Compile(a:run)
endfunction

