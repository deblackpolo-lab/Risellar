import "@testing-library/jest-dom/vitest";
import { createElement } from "react";
import type { ReactNode } from "react";
import { vi } from "vitest";

vi.mock("@clerk/nextjs", () => ({
  ClerkProvider: ({ children }: { children: ReactNode }) => children,
  SignIn: () => createElement("div", null, "Sign in"),
  SignUp: () => createElement("div", null, "Sign up"),
  useClerk: () => ({
    signOut: vi.fn()
  })
}));

Object.defineProperty(window, "matchMedia", {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn()
  }))
});

class MockIntersectionObserver {
  observe = vi.fn();
  unobserve = vi.fn();
  disconnect = vi.fn();
}

class MockResizeObserver {
  observe = vi.fn();
  unobserve = vi.fn();
  disconnect = vi.fn();
}

Object.defineProperty(window, "IntersectionObserver", { writable: true, value: MockIntersectionObserver });
Object.defineProperty(globalThis, "IntersectionObserver", { writable: true, value: MockIntersectionObserver });
Object.defineProperty(window, "ResizeObserver", { writable: true, value: MockResizeObserver });
Object.defineProperty(globalThis, "ResizeObserver", { writable: true, value: MockResizeObserver });
