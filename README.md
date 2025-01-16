# smoko

Australian slang for downing tools and taking a break for an unknown period of time. Here's a CLI tool of the same name.

You tell it when you want to go for a smoko. `smoko in 7` will make Smoko (in 7 minutes) put your displays in sleep mode (it's idiomatic to jiggle your mouse/touchpad to end a smoko).

So you can down tools for a moment. And go have a smoko.

Go drink a glass of water.

Go put your feet on some grass.

Go powernap.

Whatever.

Your screens will be right where you left them.

## Installation

### Build from Source

Currently the only option.

#### Install zig

##### Homebrew

```sh
brew install zig
```

_Optional: also install zig language server_
```sh
brew install zls
```

#### Clone the Repo

```sh
git clone git@github.com:lobes/smoko.git
cd smoko
```

#### Build Smoko

```sh
zig build
```

#### Set a smoko

```sh
smoko now
```
- immediately puts your displays in sleep mode

## Sub-Commands

Smoko is a bucket of sub commands:
`smoko now`
`smoko in 7`
`smoko at 3`
`smoko s`
`smoko pass`
`smoko moveto in 11`
`smoko moveto at noon`
`smoko wipe`
`smoko help`


### 


Smoko in x = add a smoko that will call it x mins from now

Smoko at x[am|pm] = add a smoko that will call it at next x[am|pm] (always look forwards in time)

Smoko s = give me a list of the currently queued smokos and how long until they call it

Smoko clear = terminate all smokos in the queue and tell me how long until they would have called it
