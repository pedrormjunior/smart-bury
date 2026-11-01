"""Translations of the intro's captions, for its subtitles.

The narration and the on-screen captions stay in English: these only go into
the translated TTML subtitles, with the timing of the English ones (see
`write_ttml' in smart_bury_intro.py).  Terms follow the English closely: Emacs
keys, commands, and buffer names keep their markup (see `parse_rich'), which
`check' verifies.

Run this file to check the translations, as `make demo-check' does.

"""

import ast
import re
import sys
from collections import Counter
from pathlib import Path

# Subtitles' languages, as BCP 47 tags, in the order of TRANSLATIONS' values.
LANGUAGES = ("pt-BR", "es", "it")

# Each language's Kokoro voice and espeak-ng language, for its dub (see
# dub.py), and how to say the keys the captions name.
DUB_VOICES = {
    # "pt-BR": ("pm_alex:0.75,pm_santa:0.25", "pt-br"),
    "pt-BR": ("pm_alex:0.75,pf_dora:0.25", "pt-br"),
    "es": ("em_alex", "es"),
    "it": ("im_nicola:0.75,if_sara:0.25", "it"),
}
KEY_WORDS = {
    "pt-BR": {"_": "subtraço", "-": "menos", "RET": "enter", "3": "três"},
    "es": {"_": "guion bajo", "-": "menos", "RET": "intro", "3": "tres"},
    "it": {"_": "trattino basso", "-": "meno", "RET": "invio", "3": "tre"},
}

# How the English voice says the words that stay in English.
ENGLISH_PHONEMES = {
    "smart": "smˈɑːɹt",
    "bury": "bˈɛɹi",
    "repeat": "ɹᵻpˈiːt",
    "map": "mˈæp",
    "mode": "mˈoʊd",
    "quit": "kwˈɪt",
    "window": "wˈɪndoʊ",
    "kill": "kˈɪl",
    "current": "kˈɜːɹənt",
    "buffer": "bˈʌfɚ",
    "buffers": "bˈʌfɚz",
}

# Words a language's voice mispronounces, with the phonemes to say instead,
# for its dub only.
SPOKEN_PHONEMES = {
    "pt-BR": ENGLISH_PHONEMES,
    "it": ENGLISH_PHONEMES,
    "es": {
        word: ENGLISH_PHONEMES[word]
        for word in (
            "smart",
            "bury",
            "quit",
            "window",
            "kill",
            "current",
            "buffer",
            "repeat",
            "map",
            "mode",
        )
    },
}

# Each caption, with its markup, and its translations into LANGUAGES.
TRANSLATIONS = {
    (
        "Smart Bury: keep wanted buffers at the top of the “list of all "
        "buffers”."
    ): (
        (
            "Smart Bury: mantenha os buffers desejados no topo da “lista de "
            "todos os buffers”."
        ),
        (
            "Smart Bury: mantén los búferes deseados en la parte superior de "
            "la “lista de todos los búferes”."
        ),
        (
            "Smart Bury: tieni i buffer desiderati in cima all’“elenco di "
            "tutti i buffer”."
        ),
    ),
    "Smart Bury has three basic commands:": (
        "O Smart Bury tem três comandos básicos:",
        "Smart Bury tiene tres comandos básicos:",
        "Smart Bury ha tre comandi di base:",
    ),
    (
        "switch through buffers, switch to the ~other buffer~, and bury the "
        "current one,"
    ): (
        (
            "percorrer os buffers, mudar para o ~outro buffer~ e enterrar o "
            "buffer atual,"
        ),
        "recorrer los búferes, cambiar al ~otro búfer~ y enterrar el actual,",
        (
            "scorrere i buffer, passare all’~altro buffer~ e seppellire quello"
            " corrente,"
        ),
    ),
    "all bound by {smart-bury-mode}.": (
        "todos associados a teclas pelo {smart-bury-mode}.",
        "todos asociados a teclas por {smart-bury-mode}.",
        "tutti associati a tasti da {smart-bury-mode}.",
    ),
    "Two Emacs commands are also wrapped:": (
        "Dois comandos do Emacs também são encapsulados:",
        "También se envuelven dos comandos de Emacs:",
        "Anche due comandi di Emacs vengono incapsulati:",
    ),
    "|quit-window| and |kill-current-buffer|,": (
        "|quit-window| e |kill-current-buffer|,",
        "|quit-window| y |kill-current-buffer|,",
        "|quit-window| e |kill-current-buffer|,",
    ),
    "which, once wrapped, continue the same ~smart sequence~.": (
        (
            "que, depois de encapsulados, continuam a mesma ~sequência "
            "smart~."
        ),
        "que, una vez envueltos, continúan la misma ~secuencia smart~.",
        (
            "che, una volta incapsulati, proseguono la stessa ~sequenza "
            "smart~."
        ),
    ),
    "Emacs keeps a “list of all buffers”.": (
        "O Emacs mantém uma “lista de todos os buffers”.",
        "Emacs mantiene una “lista de todos los búferes”.",
        "Emacs mantiene un “elenco di tutti i buffer”.",
    ),
    "The first is the ~current buffer~; the second, the ~other buffer~.": (
        "O primeiro é o ~buffer atual~; o segundo, o ~outro buffer~.",
        "El primero es el ~búfer actual~; el segundo, el ~otro búfer~.",
        "Il primo è il ~buffer corrente~; il secondo, l’~altro buffer~.",
    ),
    "Usually, going to a third buffer means typing its name:": (
        "Em geral, ir para um terceiro buffer exige digitar o nome dele:",
        "Normalmente, ir a un tercer búfer implica escribir su nombre:",
        "Di solito, per andare a un terzo buffer bisogna digitarne il nome:",
    ),
    'Here, `C-x b`, then typing "C".': (
        'Aqui, `C-x b` e depois digitar "C".',
        'Aquí, `C-x b` y luego escribir "C".',
        'Qui, `C-x b` e poi digitare "C".',
    ),
    'Then `C-x b` `RET` is enough to come back to "A", the ~other buffer~.': (
        'Depois, `C-x b` `RET` basta para voltar a "A", o ~outro buffer~.',
        'Después, basta `C-x b` `RET` para volver a "A", el ~otro búfer~.',
        'Poi basta `C-x b` `RET` per tornare ad "A", l’~altro buffer~.',
    ),
    'This leaves "C" ahead of "B".': (
        'Isso deixa "C" à frente de "B".',
        'Esto deja "C" por delante de "B".',
        'Così "C" resta davanti a "B".',
    ),
    "Putting the list back in order takes more typing.": (
        "Recolocar a lista em ordem exige digitar mais.",
        "Volver a ordenar la lista requiere escribir más.",
        "Per rimettere in ordine l’elenco bisogna digitare ancora.",
    ),
    "Smart Bury moves through buffers without typing names…": (
        "O Smart Bury percorre os buffers sem digitar nomes…",
        "Smart Bury recorre los búferes sin escribir nombres…",
        "Smart Bury scorre i buffer senza digitare nomi…",
    ),
    "…and keeps the list in order.": (
        "…e mantém a lista em ordem.",
        "…y mantiene la lista en orden.",
        "…e mantiene in ordine l’elenco.",
    ),
    "Smart Bury remembers where a ~sequence~ started and how deep it is.": (
        (
            "O Smart Bury lembra onde uma ~sequência~ começou e até onde ela "
            "avançou."
        ),
        (
            "Smart Bury recuerda dónde empezó una ~secuencia~ y hasta dónde ha"
            " avanzado."
        ),
        (
            "Smart Bury ricorda dove è iniziata una ~sequenza~ e fin dove è "
            "arrivata."
        ),
    ),
    '`C-x _` goes to the ~other buffer~, "B".': (
        '`C-x _` vai para o ~outro buffer~, "B".',
        '`C-x _` va al ~otro búfer~, "B".',
        '`C-x _` va all’~altro buffer~, "B".',
    ),
    "Each `_` goes one buffer deeper, burying nothing.": (
        "Cada `_` avança mais um buffer, sem enterrar nada.",
        "Cada `_` avanza un búfer más, sin enterrar nada.",
        "Ogni `_` avanza di un altro buffer, senza seppellire nulla.",
    ),
    'Buffer "A", where the ~sequence~ started, stays the ~other buffer~.': (
        (
            'O buffer "A", onde a ~sequência~ começou, continua sendo o ~outro'
            " buffer~."
        ),
        (
            'El búfer "A", donde empezó la ~secuencia~, sigue siendo el ~otro '
            "búfer~."
        ),
        (
            'Il buffer "A", dove è iniziata la ~sequenza~, resta l’~altro '
            "buffer~."
        ),
    ),
    'Past the last buffer, it wraps around to "A".': (
        'Depois do último buffer, volta ao início, em "A".',
        'Tras el último búfer, vuelve al principio, a "A".',
        'Dopo l’ultimo buffer, ricomincia da "A".',
    ),
    "Typing, or any other command, ends the ~sequence~.": (
        "Digitar, ou qualquer outro comando, encerra a ~sequência~.",
        "Escribir, o cualquier otro comando, termina la ~secuencia~.",
        "Digitare, o qualsiasi altro comando, chiude la ~sequenza~.",
    ),
    '`C-x M-_` also switches to the ~other buffer~, "B"…': (
        '`C-x M-_` também muda para o ~outro buffer~, "B"…',
        '`C-x M-_` también cambia al ~otro búfer~, "B"…',
        'Anche `C-x M-_` passa all’~altro buffer~, "B"…',
    ),
    "…and `M-_` switches back and forth, as many times as needed.": (
        "…e `M-_` alterna entre os dois, quantas vezes for preciso.",
        "…y `M-_` alterna entre ambos, tantas veces como haga falta.",
        "…e `M-_` alterna tra i due, tutte le volte che serve.",
    ),
    'To get to "D": `_` `_` `_`.': (
        'Para chegar a "D": `_` `_` `_`.',
        'Para llegar a "D": `_` `_` `_`.',
        'Per arrivare a "D": `_` `_` `_`.',
    ),
    "Then `M-_` goes back to the ~initial buffer~.": (
        "Depois, `M-_` volta ao ~buffer inicial~.",
        "Después, `M-_` vuelve al ~búfer inicial~.",
        "Poi `M-_` torna al ~buffer iniziale~.",
    ),
    'To get to "C": `C-x _` `_`.': (
        'Para chegar a "C": `C-x _` `_`.',
        'Para llegar a "C": `C-x _` `_`.',
        'Per arrivare a "C": `C-x _` `_`.',
    ),
    'To get to "B": `C-x _` `_`.': (
        'Para chegar a "B": `C-x _` `_`.',
        'Para llegar a "B": `C-x _` `_`.',
        'Per arrivare a "B": `C-x _` `_`.',
    ),
    'And back to "A": `C-x _` `_` again.': (
        'E de volta a "A": `C-x _` `_` de novo.',
        'Y de vuelta a "A": `C-x _` `_` otra vez.',
        'E si torna ad "A": di nuovo `C-x _` `_`.',
    ),
    "This way, we easily cycle among three buffers.": (
        "Assim, alternamos facilmente entre três buffers.",
        "Así, alternamos fácilmente entre tres búferes.",
        "Così passiamo facilmente da uno all’altro di tre buffer.",
    ),
    "`C-x M--` buries the ~current buffer~.": (
        "`C-x M--` enterra o ~buffer atual~.",
        "`C-x M--` entierra el ~búfer actual~.",
        "`C-x M--` seppellisce il ~buffer corrente~.",
    ),
    "Each further `M--` does the same…": (
        "Cada novo `M--` faz o mesmo…",
        "Cada nuevo `M--` hace lo mismo…",
        "Ogni altro `M--` fa lo stesso…",
    ),
    'Heading for "D", `_` first goes to "B"…': (
        'A caminho de "D", `_` primeiro vai para "B"…',
        'Camino de "D", `_` va primero a "B"…',
        'Diretti a "D", `_` va prima a "B"…',
    ),
    '…and `M--` buries "B", going on to "C", not back to "A".': (
        '…e `M--` enterra "B", seguindo para "C", sem voltar a "A".',
        '…y `M--` entierra "B", siguiendo a "C", sin volver a "A".',
        (
            '…e `M--` seppellisce "B", proseguendo verso "C", senza tornare ad'
            ' "A".'
        ),
    ),
    'One more `_` reaches "D", leaving "C" near the top for later.': (
        'Mais um `_` chega a "D", deixando "C" perto do topo para depois.',
        (
            'Un `_` más llega a "D", dejando "C" cerca de la parte superior '
            "para después."
        ),
        'Un altro `_` arriva a "D", lasciando "C" vicino alla cima per dopo.',
    ),
    "`C-x 3`^ splits the window and arms the repeat map.": (
        "`C-x 3`^ divide a janela e ativa o ~repeat map~.",
        "`C-x 3`^ divide la ventana y activa el ~repeat map~.",
        "`C-x 3`^ divide la finestra e attiva la ~repeat map~.",
    ),
    'So `_` right away shows "A"…': (
        'Assim, `_` logo em seguida mostra "A"…',
        'Así, `_` muestra "A" de inmediato…',
        'Così `_` mostra subito "A"…',
    ),
    '…and another `_` goes on to "C".': (
        '…e outro `_` segue para "C".',
        '…y otro `_` sigue a "C".',
        '…e un altro `_` prosegue verso "C".',
    ),
    "That’s Smart Bury.": (
        "Esse é o Smart Bury.",
        "Eso es Smart Bury.",
        "Questo è Smart Bury.",
    ),
    "To try it, enable {smart-bury-mode} and {repeat-mode} in Emacs.": (
        "Para experimentar, ative {smart-bury-mode} e {repeat-mode} no Emacs.",
        "Para probarlo, activa {smart-bury-mode} y {repeat-mode} en Emacs.",
        "Per provarlo, attiva {smart-bury-mode} e {repeat-mode} in Emacs.",
    ),
}

MARKUP = re.compile(r"`[^`]*`|\{[^}]*\}|\|[^|]*\||\"[^\"]*\"|\^")


def translated(text: str, language: str) -> str:
    """Caption TEXT in LANGUAGE, one of LANGUAGES or "en".

    A caption without a translation stays in English, with a warning,
    rather than losing a render at its very end.

    """
    if language == "en":
        return text
    if text not in TRANSLATIONS:
        print(f"no translation of caption: {text}", file=sys.stderr)
        return text
    return TRANSLATIONS[text][LANGUAGES.index(language)]


def problems(captions: dict, source: set[str]) -> list[str]:
    """What is wrong with CAPTIONS, shaped like TRANSLATIONS, given SOURCE,
    the scene's strings: captions the scene doesn't have, and translations
    missing, or whose markup differs from the caption's."""
    found = []
    for caption, translations in captions.items():
        if caption not in source:
            found.append(f"not in the scene: {caption}")
        if len(translations) != len(LANGUAGES):
            found.append(f"not one per language: {caption}")
        for language, text in zip(LANGUAGES, translations):
            if Counter(MARKUP.findall(text)) != Counter(
                MARKUP.findall(caption)
            ):
                found.append(f"markup differs in {language}: {text}")
            if text.count("~") % 2:
                found.append(f"unbalanced italics in {language}: {text}")
            for keys in re.findall(r"`([^`]*)`", text):
                for key in keys.split():
                    name = key.rsplit("-", 1)[-1] or "-"
                    if len(name) > 1 or not name.isalpha():
                        if name not in KEY_WORDS[language]:
                            found.append(f"unnamed {key} in {language}")
    return found


def scene_strings() -> set[str]:
    """The strings in the scene's source, the title's caption included, which
    it builds from TAGLINE.

    """
    tree = ast.parse(
        Path(__file__).with_name("smart_bury_intro.py").read_text("utf-8")
    )
    strings = {
        node.value
        for node in ast.walk(tree)
        if isinstance(node, ast.Constant) and isinstance(node.value, str)
    }
    tagline = next(s for s in strings if s.startswith("Keep wanted buffers"))
    return strings | {f"Smart Bury: {tagline[0].lower()}{tagline[1:]}."}


def check() -> None:
    """Exit with an error if the translations have any problem."""
    found = problems(TRANSLATIONS, scene_strings())
    # A caption that must fail, so this check can't silently do nothing.
    assert problems({"`C-x _`": ("`C-x`", "`C-x _`", "`C-x _`")}, {"`C-x _`"})
    if found:
        sys.exit("\n".join(found))
    print(f"{len(TRANSLATIONS)} captions translated into {len(LANGUAGES)}.")


if __name__ == "__main__":
    check()
