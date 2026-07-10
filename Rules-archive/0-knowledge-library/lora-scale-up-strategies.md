# LoRA Scale-Up Strategies: 7B to 14B / 30B

Question: can a LoRA trained on a 7B base be ported to a 14B base, and is that advantageous? Research summary for the EMSU fleet, real 2025-2026 citations only.

## 1. Direct LoRA cross-base transfer: NOT supported

A LoRA adapter is a pair of low-rank matrices `(A, B)` sized to specific tensor shapes of one base model (hidden_size, num_attention_heads, num_kv_heads, num_layers, intermediate_size). Qwen2.5-Coder-7B has 28 layers and hidden 3584; Qwen2.5-Coder-14B has 48 layers and hidden 5120; Qwen2.5-Coder-32B has 64 layers and hidden 5120. A 7B-trained adapter literally cannot be loaded onto a 14B base because every target tensor has a different shape. The HuggingFace PEFT library enforces this via `target_modules` and `base_model_name_or_path` in `adapter_config.json` (PEFT docs, peft.LoraConfig, 2025). Workarounds proposed in research (e.g. Trans-LoRA, ICML 2024 followups in 2025) require a learned projector and have not landed in mainline PEFT as of 2025-11. Practical answer: no.

## 2. Knowledge distillation 7B teacher to 14B student (reverse distillation)

Traditional distillation is teacher_large to student_small. The reverse direction (7B teacher to 14B student) is unusual but legitimate when the 7B holds domain knowledge the 14B base lacks. Two concrete tools as of 2025-2026:

- HuggingFace TRL `GKDTrainer` (Generalized Knowledge Distillation, Agarwal et al. 2024, productionised in TRL 0.10+, still maintained in TRL v1.4.0 2025-10), supports on-policy KL-divergence training with any teacher and student size combination. See `huggingface.co/docs/trl/main/en/gkd_trainer`.
- TRL experimental `DistillationTrainer` and `MiniLLMTrainer` (TRL main, 2025) for forward-KL and reverse-KL setups.
- OpenAI's Weak-to-Strong Generalization paper (Burns et al., arxiv 2312.09390, 2023) is the theoretical backing: a weaker model's labels can elicit stronger capability in a larger student, with a recoverable performance gap. Their GPT-2 to GPT-4 experiments show ~50-70% of the gap is recovered with naive fine-tuning and more with auxiliary confidence losses.

This is closely related to the practical path below (synthetic-data bootstrap) which is the realistic implementation.

## 3. Model merging and FrankenMerges (MergeKit)

`arcee-ai/mergekit` (github.com/arcee-ai/mergekit, 300+ commits as of 2025-10, EMNLP 2024 industry track paper Goddard et al. 2024.emnlp-industry.36) supports: linear, SLERP, NuSLERP, Multi-SLERP, Karcher, task_arithmetic, TIES (Yadav et al. NeurIPS 2023), DARE (Yu et al. ICML 2024), DELLA, Model Breadcrumbs, SCE, Model Stock, Nearswap, Arcee Fusion, and Passthrough. All same-size merges (TIES, DARE, SLERP) require identical architectures, so 7B-into-14B is NOT supported by these methods. They only work between two 7Bs, two 14Bs, etc. MergeKit also ships `mergekit-extract-lora` which goes the OTHER direction: extract a LoRA from a fine-tuned model relative to its base, useful for republishing the EMSU 7B as a portable adapter.

## 4. Depth Up-Scaling (the only "make it bigger" merge)

SOLAR 10.7B (Kim et al., arxiv 2312.15166, Upstage AI, 2023-12, accepted NAACL 2024) introduced Depth Up-Scaling (DUS): take a 7B model with 32 layers, duplicate the middle 24 layers, concat to produce a 48-layer model (~10.7B params), then continue pretraining briefly. SOLAR 10.7B-Instruct beat Mixtral-8x7B-Instruct on MT-Bench at release. MergeKit implements this exactly via the `passthrough` merge method (frankenmerge) per the mergekit README. Reddit r/LocalLLaMA case studies on Qwen2.5 passthrough merges (2024-2025) report 3-7% gains on long-context tasks but degraded short-context coherence unless followed by continued pretraining. For EMSU this would mean: passthrough the email-7b-lora-v2 GGUF into a ~10.7B frankenmodel, then re-quantise. Cheap but unpredictable.

## 5. Synthetic-data bootstrap (the realistic path)

Use the 7B-LoRA to generate a corpus, then fine-tune a fresh 14B-LoRA on it. Foundational references:

- Self-Instruct (Wang et al., arxiv 2212.10560, ACL 2023): bootstrap instruction data from a seed model. 50k+ generated examples lifted GPT-3 to InstructGPT-comparable behaviour.
- Alpaca, WizardLM, Orca (2023-2024) all use the same principle.
- Critique Fine-Tuning, CFT (Wang/Yue/Chen, arxiv 2501.17703, 2025-01): only 50k synthetic critique pairs trained Qwen2.5-Math-CFT in 1 hour on 8xH100 to match Qwen2.5-Math-Instruct which used 2M+ samples and far more compute. Demonstrates that small high-quality synthetic corpora are the dominant 2025 paradigm.
- HuggingFace `distilabel` framework (argilla-io/distilabel, 2024-2025) and the SmolLM2 cookbook are the canonical 2025 toolchains.

For EMSU: run email-7b:lora-v2 against the real student-email corpus to produce 20k-50k context-rich Q&A pairs, then SFT Qwen2.5-Coder-14B (or 32B) with PEFT/LoRA on that synthetic set. The 14B base brings stronger reasoning while the synthetic corpus transmits the 7B's EMSU-specific behaviour.

## Qwen2.5-Coder family note

Per the Qwen HuggingFace model card (huggingface.co/Qwen/Qwen2.5-Coder-14B, base_model: Qwen/Qwen2.5-14B, Qwen2.5-Coder Technical Report arxiv 2409.12186): Qwen2.5-Coder ships at 0.5B, 1.5B, 3B, 7B, 14B, 32B with the SAME tokenizer, SAME chat template (im_start/im_end ChatML), and SAME pretraining-stage code corpus. Architecture differs only in width/depth. This means option 5 (synthetic-data bootstrap onto 14B-Coder) is mechanically straightforward: same tokenizer, same chat template, same domain pretraining, only the LoRA needs to be retrained.

## Recommended path for EMSU

Synthetic-data distillation onto Qwen2.5-Coder-14B-Instruct using 20k EMSU-context pairs generated by email-7b:lora-v2. Cost on RunPod A100-80GB: roughly $20-40 for the generation pass plus the LoRA SFT (QLoRA, rank 32, 3 epochs, batch 4). Verify corpus exists on Artemis at `/opt/lora-training/training_data/` before scheduling. If corpus is intact, option 5 collapses into a same-base re-train of 14B on the original 7B training data, which is the most predictable path of all.

## Cost comparison (RunPod A100-80GB at $1.89/hr as of 2025-11)

| Path | Training hours | $ estimate | Predictability |
|---|---|---|---|
| Synthetic-data distill, 20k pairs, 14B QLoRA r32 3ep | 10-20h | $20-40 | High |
| Same-base re-train, 14B QLoRA on original corpus | 20-40h | $40-80 | Very high |
| Depth upscale 7B to 10.7B via mergekit passthrough | 1-2h merge + 5-10h CPT | $10-20 | Low |
| Direct LoRA port 7B to 14B | impossible | n/a | n/a |
| MergeKit TIES/DARE 14B-into-14B (if we had two 14Bs) | 1-2h on CPU | <$5 | Medium |

## Concrete generation recipe for path 5

1. Pull `email-7b:lora-v2` on Artemis.
2. Source 5k seed prompts from the real EMSU ticket archive (anonymized).
3. For each seed, generate 4 response variants with temperature 0.7, top_p 0.9 against the 7B-LoRA. Use vLLM batched generation for throughput; vLLM 0.6+ does 7B Qwen at ~2000 tok/s on a single A100 (vllm-project/vllm releases, 2025).
4. Filter with a critic prompt (Qwen2.5-32B-Instruct as judge, Critique Fine-Tuning style per arxiv 2501.17703).
5. Save as a JSONL `messages` dataset, push to HuggingFace as a private dataset.
6. SFT Qwen2.5-Coder-14B-Instruct with TRL `SFTTrainer` + PEFT QLoRA (rank 32, alpha 64, lr 2e-4, cosine, 3 epochs, packing on). See `huggingface.co/docs/trl/main/en/sft_trainer` and the LoRA Without Regret guide added to TRL docs in 2025.
7. Merge adapter, convert to GGUF with `convert_hf_to_gguf.py` (llama.cpp, 2025), quantise to Q4_K_M, build modelfile with Qwen ChatML template, push as `email-14b:lora-v2`.

## What we should DO NEXT

1. Verify `ls /opt/lora-training/training_data/` on Artemis. If the 7B corpus exists -> path "same-base re-train 14B".
2. If corpus is gone or partial -> path 5 (synthetic-data bootstrap), starting with 5k seeds from the ticket archive.
3. Skip MergeKit passthrough (path 4) until paths 1 or 2 are baselined; depth upscaling rewards exploration but is not the right risk for a production fleet.
4. Skip direct LoRA porting (path 1) entirely; not supported.
