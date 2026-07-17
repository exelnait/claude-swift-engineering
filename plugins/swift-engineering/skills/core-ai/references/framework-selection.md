# Framework Selection: Core AI vs Foundation Models vs MLX

> Core AI is a brand-new framework announced at WWDC 2026; details here are high-level and evolving. Confirm availability, exact API surface, and toolchain against current Apple documentation before relying on any specifics.

At WWDC 2026 Apple framed three complementary ways to add intelligence to an app: enhance experiences through natural language with **Siri**, build AI features with the **Foundation Models framework**, and **run your own models on device with Core AI** — with **MLX** for the enthusiast/research end. This guide covers choosing between the three *model* frameworks. All descriptions are at the capability/positioning level from the talk; no Core AI or MLX API is reproduced here.

## Decision guide

```
What are you shipping?

Do you have / need a SPECIFIC custom model of your own to run on device?
├─ NO  → Foundation Models framework          (the default for most apps)
└─ YES → Are you shipping it inside your app, on device?
         ├─ YES → Core AI
         └─ NO (experimenting / training / researching /
                fine-tuning / local inference server) → MLX
```

If you find yourself about to pick Core AI, first confirm the feature genuinely needs *your* model. Most generative features do not — Foundation Models already exposes Apple and third-party LLMs behind one Swift API.

## Foundation Models framework — the default

Use Apple and third-party LLMs through **one native Swift API**, with the flexibility to get the right model for the job:

- Backing options: the **on-device** model, **Private Cloud Compute** (bigger, private), and **server / third-party** models.
- The default for most generative features — summarization, extraction, classification, structured output, chat, tool calling.
- Rich supporting tools (Evaluations, the Foundation Models instrument, an FM command-line tool, a Python SDK) and, later, an open-source implementation that also runs on your server.

**→ For anything in this category, use the `foundation-models` skill.** Reach past it only when the model must be specifically yours.

## Core AI — bring and run YOUR model on device

Apple's framing: *"When you want to bring a specific model into your app and run it on device, there's Core AI,"* and *"If you're using a custom model to power a feature within your app, Core AI is the right technology to use."* Described capabilities:

- **Memory-safe Swift API** for uncompromising performance.
- **Extensive tuning**: fine-grained tuning Apple called "interest management," model specialization, and custom GPU kernels.
- **Python-based tools** to **convert and optimize PyTorch models** for the Core AI runtime.
- **New developer toolchain**: **ahead-of-time compilation**, dedicated **Core AI Instruments**, and a **visual debugger** that traces tensor values directly back to your original Python source code.
- **Scales with available compute**: a compact vision model on iPhone for real-time camera queries, up to a **multi-billion-parameter LLM on Mac** for agentic, multi-step workflows.
- **On device**: zero server dependencies, **zero token cost**, optimized for Apple silicon.
- Built into the platform (so apps benefit from ongoing fixes and enhancements) and powers Apple Intelligence experiences, including **Siri**.

Trade-off: the ceiling is the device's compute, and you are responsible for sourcing, converting, and maintaining the model. In exchange you get full on-device privacy and no per-token cost.

## MLX — experiment, train, research, serve

For the enthusiast/research path — **not** an app-shipping runtime:

- For **experimenting with, training, researching, or fine-tuning** generative models, or running a **local inference server**.
- Open-source array framework; now supports **Metal 4** and **GPU Neural Accelerators**.
- Can **scale training across multiple Macs** via **RDMA over Thunderbolt**; faster than ever.

## Quick reference

| | Foundation Models | Core AI | MLX |
|---|---|---|---|
| Primary job | Generative features via Apple/third-party LLMs | Ship & run **your** custom model on device | Experiment / train / research / fine-tune / serve |
| Model source | Provided (on-device, PCC, server) | Your model (e.g. converted from PyTorch) | Your model / research models |
| Where it runs | On-device, Private Cloud Compute, or server | On device (iPhone → Mac), scales to compute | Local (dev/research), multi-Mac training |
| Token cost | Free on-device/PCC; per-token for server | Zero | N/A (local) |
| Default for most apps? | **Yes** | No — only for a specific custom model | No — not a shipping runtime |
| Related skill | `foundation-models` | this skill (`core-ai`) | — |
