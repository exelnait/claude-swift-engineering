---
name: core-ai
description: Use when bringing and running your OWN custom ML model on device with Apple's new Core AI framework — memory-safe Swift API, PyTorch→Core AI conversion tooling, ahead-of-time compilation, Core AI Instruments and the tensor visual debugger — or when deciding between Core AI, the Foundation Models framework, and MLX for an on-device AI feature.
---

# Core AI

> Core AI is a brand-new framework announced at WWDC 2026; details here are high-level and evolving. Confirm availability, exact API surface, and toolchain against current Apple documentation before relying on any specifics.

## Overview

Core AI is a **brand-new Apple framework**, introduced at WWDC 2026 ("Platforms State of the Union"), for bringing a **specific, custom model** into your app and running it entirely **on device**. Apple positions it as "the best way to bring and run models on device," delivered through a modern **memory-safe Swift API** and built directly into the platform.

Reach for Core AI only when you already have your own model to ship — e.g. a PyTorch model you convert, or a model you want to specialize. For most generative features (summarize, extract, classify, chat, tool-calling over an LLM) **do not start here** — start with the **Foundation Models framework** (see the `foundation-models` skill), which exposes Apple and third-party LLMs behind one Swift API. Core AI is the deeper, more specialized path for a model that is *yours*.

The talk describes Core AI only at the capability/positioning level — **no Core AI code or public API was shown**, so treat everything below as high-level and unverified:

- Memory-safe Swift API with extensive tuning capabilities: fine-grained tuning Apple called "interest management," model specialization, and custom GPU kernels.
- **Python-based tools** alongside the framework to **convert and optimize PyTorch models** for the Core AI runtime.
- Deep integration into a new developer toolchain: **ahead-of-time compilation**, dedicated **Core AI Instruments**, and a **visual debugger** that traces tensor values back to your original Python source.
- Engineered to **scale with available compute** — from a compact vision model on iPhone (real-time camera queries) to a multi-billion-parameter LLM on Mac (agentic, multi-step workflows).
- Runs fully on device: **zero server dependencies, zero token cost**, optimized for Apple silicon. It also powers Apple Intelligence experiences across the system, including Siri.

## Framework selection

Apple frames three complementary, on-device-capable paths. Pick by *what you are shipping*, not by which is newest.

| You are... | Use | Why |
|------------|-----|-----|
| Building a generative feature (summarize/extract/classify/chat) with an Apple or third-party LLM | **Foundation Models framework** | One Swift API over on-device, Private Cloud Compute, and server models. The default for most apps. See the `foundation-models` skill. |
| Shipping **your own / a specific custom model** in-app, running on device | **Core AI** | Memory-safe Swift API, PyTorch conversion tools, AOT compilation, Core AI Instruments + tensor debugger; scales iPhone → Mac. |
| Experimenting, training, researching, fine-tuning, or running a local inference server | **MLX** | Open-source array framework; Metal 4, GPU Neural Accelerators, multi-Mac training over Thunderbolt. Not an app-shipping runtime. |

Rule of thumb from the keynote: *"If you're using a custom model to power a feature within your app, Core AI is the right technology to use."* If the model is not specifically yours, Foundation Models almost certainly already covers it.

See **[references/framework-selection.md](references/framework-selection.md)** for the full decision guide.

## Common Mistakes

1. **Reaching for Core AI when Foundation Models already covers the need.** Summarization, extraction, classification, structured output, and chat over an Apple/third-party LLM are the Foundation Models framework's job — one Swift API, no model to source, convert, or maintain. Core AI is for when you must ship a *specific custom model* of your own. Defaulting to Core AI is more work for no benefit.

2. **Assuming a concrete API from this skill.** The talk showed no Core AI code. Do not scaffold against invented type names, initializers, or Python entry points — confirm the real surface against current Apple documentation first.

3. **Treating MLX as a shipping runtime.** MLX is for experimenting, training, researching, fine-tuning, or a local inference server — not for shipping a model inside a distributed app. For the in-app on-device case, that is Core AI.

4. **Expecting frontier-server behavior.** Core AI is on-device — its ceiling is the device's compute (a multi-billion-parameter LLM is cited on *Mac*, not iPhone). It trades zero token cost and full privacy for that constraint; size the model to the target hardware.

5. **Not confirming availability and toolchain.** This is a first-year framework. Availability, supported platforms, conversion tooling, and Instruments/debugger support are all evolving — verify against current docs before committing.
