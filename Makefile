.PHONY: test compile checkdoc package-lint demo-check demo-preview	\
	demo intro-check intro intro-part intro-thumbnail intro-play	\
	intro-narration voice-models voice-model-timed			\
	voice-model-check voice-model-clean voice-samples		\
	test-interactively test-emacs-defaults-interactively

test:
	emacs -batch -l ert -l smart-bury.el -l smart-bury-tests.el \
	  -f ert-run-tests-batch-and-exit

compile:
	emacs -batch --eval "(setq byte-compile-error-on-warn t)" \
	  -f batch-byte-compile smart-bury.el
	rm -f smart-bury.elc

checkdoc:
	emacs -batch -l checkdoc --eval \
	  "(progn (defvar warnings 0) \
	          (setq checkdoc-verb-check-experimental-flag t) \
	          (advice-add 'display-warning :before \
	                      (lambda (&rest _) (setq warnings (1+ warnings)))) \
	          (checkdoc-file \"smart-bury.el\") \
	          (kill-emacs (min warnings 1)))"

# Uses package-lint from the user's installed packages when available;
# otherwise (e.g. in CI) installs it from MELPA into a local .elpa/.
package-lint:
	emacs -batch --eval \
	  "(progn (package-initialize) \
	          (unless (require 'package-lint nil t) \
	            (setq package-user-dir (expand-file-name \".elpa\")) \
	            (add-to-list 'package-archives \
	                         '(\"melpa\" . \"https://melpa.org/packages/\") t) \
	            (package-initialize) \
	            (package-refresh-contents) \
	            (package-install 'package-lint) \
	            (require 'package-lint)))" \
	  -f package-lint-batch-and-exit smart-bury.el

# The demo animation lives in demo/, a separate uv project (see
# demo/pyproject.toml).  demo-check replays the README cases on the
# Python model of the algorithm that drives the animation.
demo-check:
	cd demo && uv run python smart_bury_sim.py
	cd demo && uv run python translations.py
	cd demo && uv run python dub.py

# Fast, low-quality render (480p15) into
# demo/smart-bury-demo-preview.mp4.
demo-preview: demo-check
	cd demo && uv run manim -ql --media_dir media \
	  -o smart-bury-demo-preview smart_bury_demo.py SmartBuryDemo
	cp demo/media/videos/smart_bury_demo/480p15/smart-bury-demo-preview.mp4 demo/

# Final render (1080p60) into demo/smart-bury-demo.mp4.
demo: demo-check
	cd demo && uv run manim -qh --media_dir media \
	  -o smart-bury-demo smart_bury_demo.py SmartBuryDemo
	cp demo/media/videos/smart_bury_demo/1080p60/smart-bury-demo.mp4 demo/

# The short introduction (demo/smart_bury_intro.py).  intro-check runs
# the scene without rendering, which asserts every storyboard step's
# expected buffer order against the model.
intro-check: demo-check
	cd demo && uv run manim --dry_run smart_bury_intro.py SmartBuryIntro

# Quality of `make intro' (resolution and frame rate): uncomment one
# line, or pass it, e.g. make intro INTRO_QUALITY=1440p60.
# INTRO_QUALITY = 480p15
# INTRO_QUALITY = 720p30
# INTRO_QUALITY = 1080p60
# INTRO_QUALITY = 1440p60
INTRO_QUALITY = 2160p60

# Manim's --quality flag for each, which also names the folder Manim
# renders into.
MANIM_QUALITY_480p15 = l
MANIM_QUALITY_720p30 = m
MANIM_QUALITY_1080p60 = h
MANIM_QUALITY_1440p60 = p
MANIM_QUALITY_2160p60 = k

# Narrator's voice in `make intro' (see demo/narration.py): a Kokoro
# voice or a blend, NAME:WEIGHT,...; empty for a silent render: make
# intro VOICE=
VOICE = am_michael:0.7,bm_george:0.3

# Loudness of the narrated video, in LUFS: about what YouTube aims
# for.  YouTube turns louder videos down, but doesn't turn quieter
# ones up, and Kokoro's voice comes out around -26.
INTRO_LOUDNESS = -14

# Render in INTRO_QUALITY, narrated in VOICE, into
# demo/smart-bury-intro-INTRO_QUALITY.mp4, with the captions as
# subtitles in demo/smart-bury-intro-INTRO_QUALITY.srt and, styled,
# .ttml, and their translations (demo/translations.py) next to them,
# e.g. demo/smart-bury-intro-INTRO_QUALITY.pt-BR.ttml.  The narration
# is raised to INTRO_LOUDNESS with ffmpeg, the video stream being
# copied as is.  A narrated render also gets a dubbed audio track per
# translation (demo/dub.py), e.g.
# demo/smart-bury-intro-INTRO_QUALITY.pt-BR.wav.
INTRO_OUTPUT = demo/media/videos/smart_bury_intro/$(INTRO_QUALITY)/smart-bury-intro
intro: demo-check $(if $(VOICE),voice-models voice-model-timed)
	@test -n "$(MANIM_QUALITY_$(INTRO_QUALITY))" || \
	  { echo "unknown INTRO_QUALITY: $(INTRO_QUALITY)"; exit 1; }
	cd demo && SMART_BURY_VOICE=$(VOICE) \
	  uv run manim -q$(MANIM_QUALITY_$(INTRO_QUALITY)) \
	  --media_dir media -o smart-bury-intro smart_bury_intro.py SmartBuryIntro
	$(if $(VOICE),ffmpeg -y -loglevel error -i $(INTRO_OUTPUT).mp4 -c:v copy \
	  -af loudnorm=I=$(INTRO_LOUDNESS):TP=-1:LRA=11 -ar 48000 \
	  -c:a aac -b:a 192k -movflags +faststart \
	  demo/smart-bury-intro-$(INTRO_QUALITY).mp4,\
	  cp $(INTRO_OUTPUT).mp4 demo/smart-bury-intro-$(INTRO_QUALITY).mp4)
	cp $(INTRO_OUTPUT).srt demo/smart-bury-intro-$(INTRO_QUALITY).srt
	for file in demo/media/subtitles/smart-bury-intro*; do \
	  cp $$file demo/smart-bury-intro-$(INTRO_QUALITY)$${file##*smart-bury-intro}; \
	done
	$(if $(VOICE),cd demo && uv run python dub.py \
	  smart-bury-intro-$(INTRO_QUALITY) --loudness=$(INTRO_LOUDNESS))

# A frame of demo/smart-bury-intro-INTRO_QUALITY.mp4, already
# rendered, as a thumbnail for YouTube, which recommends 1280x720, in
# demo/smart-bury-intro-thumbnail.png.  THUMBNAIL_TIME, in ffmpeg's
# MM:SS, is the "smart" bury: the buffer boxes tell more about the
# video than the title card, whose text the video's title would just
# repeat.
THUMBNAIL_TIME = 2:23
intro-thumbnail:
	@test -f demo/smart-bury-intro-$(INTRO_QUALITY).mp4 || \
	  { echo "no $(INTRO_QUALITY) render: run make intro first"; exit 1; }
	ffmpeg -y -loglevel error -ss $(THUMBNAIL_TIME) \
	  -i demo/smart-bury-intro-$(INTRO_QUALITY).mp4 -frames:v 1 \
	  -vf scale=1280:720 demo/smart-bury-intro-thumbnail.png

# Play demo/smart-bury-intro-INTRO_QUALITY.mp4 in mpv with its dubbed
# audio tracks: `#' cycles through them, in the order of
# INTRO_DUB_LANGUAGES, after the video's own English one.  Starts on
# track AID, e.g. make intro-play AID=2 for Portuguese.
INTRO_DUB_LANGUAGES = pt-BR es it
AID = 1
intro-play:
	@test -f demo/smart-bury-intro-$(INTRO_QUALITY).mp4 || \
	  { echo "no $(INTRO_QUALITY) render: run make intro first"; exit 1; }
	mpv --aid=$(AID) $(foreach language,$(INTRO_DUB_LANGUAGES), \
	  --audio-file=demo/smart-bury-intro-$(INTRO_QUALITY).$(language).wav) \
	  demo/smart-bury-intro-$(INTRO_QUALITY).mp4

# Per caption, how long its part of the intro lasts without narration,
# how long its speech in VOICE lasts, and the difference (positive:
# the video waits that long for the speech).  A dry run, synthesizing
# only new or changed captions; narrated renders print the same table.
intro-narration: demo-check voice-models
	@test -n "$(VOICE)" || { echo "intro-narration needs a VOICE"; exit 1; }
	cd demo && SMART_BURY_VOICE=$(VOICE) uv run manim --dry_run \
	  smart_bury_intro.py SmartBuryIntro > media/intro-narration.log 2>&1 \
	  || { cat media/intro-narration.log; exit 1; }
	@tr '\r' '\n' < demo/media/intro-narration.log | \
	  sed -n '/^ #  scene/,/in all\.$$/p'

# Fast render of a range of the intro's animations, for iterating on
# one part: make intro-part N=120,180 (animation indexes, as in
# Manim's log) writes demo/smart-bury-intro-part.mp4.
intro-part:
	@test -n "$(N)" || { echo "usage: make intro-part N=START,END"; exit 1; }
	cd demo && uv run manim -ql --media_dir media -n $(N) \
	  -o smart-bury-intro-part smart_bury_intro.py SmartBuryIntro
	cp demo/media/videos/smart_bury_intro/480p15/smart-bury-intro-part.mp4 demo/

# Narration (demo/narration.py): Kokoro's full-precision English model
# and its voices, downloaded once from kokoro-onnx's releases.
VOICE_MODELS_URL = \
  https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0
VOICE_MODELS = demo/voice-models/kokoro-v1.0.onnx \
  demo/voice-models/voices-v1.0.bin

voice-models: $(VOICE_MODELS)

demo/voice-models/%:
	mkdir -p demo/voice-models
	curl -fL -o $@.part $(VOICE_MODELS_URL)/$* && mv $@.part $@

# Kokoro v1.0 exported with a durations output, for continuous
# synthesis and phoneme timings: demo/kokoro-export/build.sh downloads
# the export script and the original weights, exports, and checks the
# result (see demo/README.md).
VOICE_MODEL_TIMED = demo/voice-models/kokoro-v1.0-timed.onnx

voice-model-timed: $(VOICE_MODEL_TIMED)

$(VOICE_MODEL_TIMED): demo/voice-models/voices-v1.0.bin
	demo/kokoro-export/build.sh

voice-model-check: $(VOICE_MODEL_TIMED)
	cd demo && uv run python kokoro-export/check.py

# What voice-model-timed builds, removed to build it again from
# scratch.
voice-model-clean:
	rm -rf demo/voice-models/checkpoints demo/kokoro-export/export.py \
	  demo/kokoro-export/.venv $(VOICE_MODEL_TIMED)

# A few captions in each candidate voice, into demo/voice-samples/.
voice-samples: voice-models
	cd demo && uv run python narration.py --samples

test-interactively:
	emacs -Q -L . -l smart-bury -l $@

test-emacs-defaults-interactively:
	emacs -Q -L . -l $@
