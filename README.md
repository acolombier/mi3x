# Mixxx

[![GitHub latest tag](https://img.shields.io/github/tag/mixxxdj/mixxx.svg)](https://mixxx.org/download)
[![Packaging status](https://repology.org/badge/tiny-repos/mixxx.svg)](https://repology.org/metapackage/mixxx/versions)
[![Build status](https://github.com/mixxxdj/mixxx/actions/workflows/build.yml/badge.svg)](https://github.com/mixxxdj/mixxx/actions/workflows/build.yml)
[![Coverage status](https://coveralls.io/repos/github/mixxxdj/mixxx/badge.svg)](https://coveralls.io/github/mixxxdj/mixxx)
[![Zulip chat](https://img.shields.io/badge/zulip-join_chat-brightgreen.svg)](https://mixxx.zulipchat.com)
[![Donate](https://img.shields.io/opencollective/all/mixxx?label=Donate)](https://mixxx.org/donate)

[Mixxx] is Free DJ software that gives you everything you need to perform live
DJ mixes. Mixxx works on GNU/Linux, Windows, and macOS.

## Quick Start

To get started with Mixxx:

1. For live use, [download the latest stable version][download-stable].
2. For experimentation and testing, [download a development release][download-testing].
3. To live on the bleeding edge, clone the repo: `git clone https://github.com/mixxxdj/mixxx.git`

## Bug tracker

The Mixxx team uses [Github Issues][issues] to manage Mixxx development.

Have a bug or feature request? [File a bug on Github][fileabug].

Want to get involved in Mixxx development? Assign yourself a bug from the [easy
bug list][easybugs] and get started!

## Building Mixxx

Read [CONTRIBUTING.md](CONTRIBUTING.md) for build instructions, code style
guidelines, and how to open a pull request.

### Using Dev Container

> [!NOTE]
> Dev container has recently been introduced and it is likely incomplete! Currently, it's been tested with `devpod` on Zed and Codium exclusively

We provide a Dev Container definition for Mixxx, based on Ubuntu 24.04 to ensure a close similarity with the CI.

> [!TIP]
> New to [Development Containers](https://containers.dev/)? If you use VS Code, the IDE should offer you to use Dev Container when you open the Mixxx working copy folder. Otherwise,
you may consider using [devpod](https://devpod.sh/docs/developing-in-workspaces/create-a-workspace#create-a-workspace)

You can build and run Mixxx using the following command:

```bash
cd build
cmake .. -DCMAKE_EXPORT_COMPILE_COMMANDS=ON # Needed for clangd
cmake --build . -j $(nproc)
./mixxx
```

#### Using your device in Dev Container

Similar to [Fedora Toolbox's](https://github.com/containers/toolbox/blob/4f4c3c9d19d1027537f69920de46b9cf09c799b9/src/cmd/create.go#L460), the default configuration provide a comprehensive definition of mounts which will allow you to use Mixxx seamlessly in the container. (UI, audio, ...)
If you are not comfortable with this for security concern, you may want to remove some or all of the binding before starting the container.

Devices should be supported by default, thanks to the provided binds. Note that if you are encountering permission issue, check that you are not using SELinux, as this is currently not well supported in Dev Container

## Documentation

For help using Mixxx, there are a variety of options:

- [Mixxx manual][manual]
- [Mixxx wiki][wiki]
- [Hardware Compatibility]
- [Creating Skins]

## Translation

Help to spread Mixxx with translations into more languages, as well as to update and ensure the accuracy of existing translations.

- [Help translate content]
- [Mixxx i18n wiki]
- [Mixxx localization forum]
- [Mixxx glossary]

## Community

Mixxx is a vibrant community of hackers, DJs and artists. To keep track of
development and community news:

- Chat with us on [Zulip][zulip].
- Follow us on [Mastodon], [Bluesky] and [Facebook].
- Subscribe to the [Mixxx Blog][blog].
- Post on the [Mixxx forums][discourse].

## License

Mixxx is released under the GPLv2. See the LICENSE file for a full copy of the
license.

[mixxx]: https://mixxx.org
[download-stable]: https://mixxx.org/download/#stable
[download-testing]: https://mixxx.org/download/#testing
[issues]: https://github.com/mixxxdj/mixxx/issues
[fileabug]: https://github.com/mixxxdj/mixxx/issues/new/choose
[mastodon]: https://floss.social/@mixxx
[Bluesky]: https://bsky.app/profile/mixxx.bsky.social
[facebook]: https://www.facebook.com/pages/Mixxx-DJ-Software/21723485212
[blog]: https://mixxx.org/news/
[manual]: https://manual.mixxx.org/
[wiki]: https://github.com/mixxxdj/mixxx/wiki
[easybugs]: https://github.com/mixxxdj/mixxx/issues?q=is%3Aopen+is%3Aissue+label%3Aeasy
[creating skins]: https://mixxx.org/wiki/doku.php/Creating-Skins
[help translate content]: https://explore.transifex.com/mixxx-dj-software/
[Mixxx i18n wiki]: https://github.com/mixxxdj/mixxx/wiki/Internationalization
[Mixxx localization forum]: https://mixxx.discourse.group/c/translation/13
[hardware compatibility]: https://manual.mixxx.org/2.3/en/hardware/manuals.html
[zulip]: https://mixxx.zulipchat.com/
[discourse]: https://mixxx.discourse.group/
