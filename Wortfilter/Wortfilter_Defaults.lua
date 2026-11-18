-- Wortfilter: defaults. All rule strings are UTF-8.
Wortfilter = Wortfilter or {}
Wortfilter.VERSION = "0.2.0"
Wortfilter.DEFAULT_RULES = {
    { pattern = "[Gg]([Oo][Tt][Tt])", replacement = "%1", usePattern = true, enabled = true },
    { pattern = "[Gg](ö[Tt][Tt])", replacement = "%1", usePattern = true, enabled = true },
    { pattern = "[Gg](Ö[Tt][Tt])", replacement = "%1", usePattern = true, enabled = true },
}
