<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Arc\ArcThemeService;
use Illuminate\Http\Request;
use Illuminate\Http\RedirectResponse;
use Illuminate\View\View;

class ArcThemeController extends Controller
{
    public function __construct(private ArcThemeService $themeService)
    {
    }

    public function index(): View
    {
        $theme = $this->themeService->getActiveTheme();

        return view('admin.arc.themes.index', [
            'theme' => $theme,
        ]);
    }

    public function update(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'primary_color' => 'nullable|string|regex:/^#[a-fA-F0-9]{6}$/',
            'background' => 'nullable|string',
            'button_style' => 'nullable|in:rounded,square',
            'animations' => 'nullable|boolean',
        ]);

        $this->themeService->applyTheme($validated);

        return redirect()->route('admin.arc.themes.index')->with('success', 'Theme updated successfully.');
    }
}