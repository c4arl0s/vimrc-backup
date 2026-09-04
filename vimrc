" Sets how many lines of history VIM has to remember
set history=500

" Set number line
set number

" set syntax on
syntax on

set nocompatible

" Use the OS clipboard by default (on versions compiled with `+clipboard`)
set clipboard=unnamed

" Highlight searches
set hlsearch

" macro to bold a sentence
" let @b = '<80>kd<80>ku(i**^[<80><fd>a)bi**^[<80><fd>a' 

:set cursorline

" Custom Commands
command! ToLowercaseAllFile :%s/.*/\L&/gc
command! JoinParagraph normal! vipJ

call plug#begin()

" List your plugins here
Plug 'tpope/vim-sensible'

call plug#end()
