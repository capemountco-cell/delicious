import { describe, expect, it } from "vitest";

import { normalizeTidyResult, parseTidyInput } from "@/lib/tidy";

describe("tidy input", () => {
  it("accepts an http(s) url with optional fields", () => {
    expect(parseTidyInput({ url: "https://youtu.be/abc", title: "  Hi " })).toEqual({
      url: "https://youtu.be/abc",
      title: "Hi",
    });
  });

  it("rejects missing or non-web urls", () => {
    expect(parseTidyInput({})).toBeNull();
    expect(parseTidyInput({ url: "javascript:alert(1)" })).toBeNull();
    expect(parseTidyInput("nope")).toBeNull();
  });
});

describe("tidy result", () => {
  it("trims, lowercases and caps tags", () => {
    expect(
      normalizeTidyResult({ title: " Cat video ", tags: ["#Cats", "cats", "Funny", "pets", "x"] }),
    ).toEqual({ title: "Cat video", tags: ["cats", "funny", "pets"] });
  });

  it("rejects results without a title", () => {
    expect(normalizeTidyResult({ title: "", tags: [] })).toBeNull();
    expect(normalizeTidyResult(null)).toBeNull();
  });
});
