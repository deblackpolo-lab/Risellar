import { render, screen } from "@testing-library/react";
import { beforeAll, describe, expect, it, vi } from "vitest";
import {
  ProductBrowseGrid,
  ProductGridCard,
  ProductImageGallery,
  ProductImagePreviewGrid
} from "@/components/marketplace";
import { customerCheckoutMock } from "@/lib/mock/customer-checkout";
import { insightProducts } from "@/lib/mock/promotions-insights";
import { resellerCoreProducts } from "@/lib/mock/reseller-core";
import { supplierCoreMock } from "@/lib/mock/supplier-core";

describe("product image gallery and ecommerce grid polish", () => {
  beforeAll(() => {
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
  });

  it("gives core ecommerce products complete 1-5 image sets", () => {
    const products = [
      ...resellerCoreProducts,
      ...customerCheckoutMock.products,
      ...supplierCoreMock.products,
      ...insightProducts
    ];

    for (const product of products) {
      expect(product.images.length).toBeGreaterThanOrEqual(1);
      expect(product.images.length).toBeLessThanOrEqual(5);
      expect(product.imageAlt).toContain(product.name);
    }

    expect(resellerCoreProducts.find((product) => product.id === "nike-air-force-1-07-green-white")?.images).toHaveLength(5);
    expect(customerCheckoutMock.products.find((product) => product.id === "jean-paul-gaultier-le-male")?.images).toHaveLength(4);
    expect(supplierCoreMock.products.find((product) => product.id === "samsung-galaxy-a14")?.images).toHaveLength(3);
  });

  it("renders compact ecommerce grid cards with stable image frames and truncation", () => {
    const product = resellerCoreProducts[0];

    render(
      <ProductBrowseGrid ariaLabel="Featured product grid">
        <ProductGridCard
          href="/reseller/products/nike-air-force-1-07-green-white"
          name={product.name}
          category={product.category}
          price="GH₵340"
          priceLabel="Selling price"
          images={product.images}
          imageAlt={product.imageAlt}
          stockStatus={product.stockStatus}
          rating="4.8 (128)"
          badges={["Hot", "High Demand"]}
        />
      </ProductBrowseGrid>
    );

    expect(screen.getByRole("list", { name: "Featured product grid" })).toHaveClass("grid-cols-2");
    expect(screen.getByRole("link", { name: /Nike Air Force 1 '07 Green & White/i })).toHaveAttribute(
      "href",
      "/reseller/products/nike-air-force-1-07-green-white"
    );
    expect(screen.getByText("Selling price")).toBeInTheDocument();
    expect(screen.getByText("GH₵340")).toBeInTheDocument();
    expect(screen.getByLabelText(product.imageAlt)).toHaveClass("aspect-square");
  });

  it("renders carousel gallery controls with lightbox affordances", () => {
    const product = resellerCoreProducts[0];

    render(
      <ProductImageGallery
        productName={product.name}
        images={product.images}
        imageAlt={product.imageAlt}
      />
    );

    expect(screen.getByText("1 / 5")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: `View ${product.name} image 1 of 5` })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: `Show ${product.name} image 2` })).toBeInTheDocument();
    expect(screen.getByText("Tap image to view full gallery")).toBeInTheDocument();
  });

  it("shows supplier upload guidance for up to five product images", () => {
    const product = supplierCoreMock.products[0];

    render(
      <ProductImagePreviewGrid
        productName={product.name}
        images={product.images}
        imageAlt={product.imageAlt}
      />
    );

    expect(screen.getByText("3 / 5 images added")).toBeInTheDocument();
    expect(screen.getByText("Upload up to 5 product images.")).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Crop & preview images" })).toBeInTheDocument();
    expect(screen.getByText("Images will be cropped and compressed before backend upload is connected.")).toBeInTheDocument();
  });
});
