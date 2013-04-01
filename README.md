jetiblogin
==========

Jetib Login Tool

This script will log you in to a jetib (Jet Internet Billing) system

It will first attempt to load your credentials from .jetibcreds
If this file doesn't exist, it will fall back to asking for your
credentials first via zenity, and if zenity isn't installed then via
normal shell input

curl must be installed and in your path for this tool to work

