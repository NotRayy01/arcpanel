<?php

namespace Pterodactyl\Http\Controllers\Admin;

use Pterodactyl\Http\Controllers\Controller;
use Pterodactyl\Services\Arc\ArcPluginService;
use Illuminate\Http\Request;
use Illuminate\Http\RedirectResponse;
use Illuminate\View\View;

class ArcPluginController extends Controller
{
    public function __construct(private ArcPluginService $pluginService)
    {
    }

    public function index(): View
    {
        $availablePlugins = $this->pluginService->fetchAvailablePlugins();
        $installedPlugins = $this->pluginService->getInstalledPlugins();

        return view('admin.arc.plugins.index', [
            'availablePlugins' => $availablePlugins,
            'installedPlugins' => $installedPlugins,
        ]);
    }

    public function install(Request $request): RedirectResponse
    {
        $request->validate([
            'name' => 'required|string',
        ]);

        try {
            $this->pluginService->installPlugin($request->input('name'));
            return redirect()->route('admin.arc.plugins.index')->with('success', 'Plugin installed successfully.');
        } catch (\Exception $e) {
            return redirect()->route('admin.arc.plugins.index')->with('error', 'Failed to install plugin: ' . $e->getMessage());
        }
    }

    public function enable(Request $request): RedirectResponse
    {
        $request->validate([
            'name' => 'required|string',
        ]);

        try {
            $this->pluginService->enablePlugin($request->input('name'));
            return redirect()->route('admin.arc.plugins.index')->with('success', 'Plugin enabled.');
        } catch (\Exception $e) {
            return redirect()->route('admin.arc.plugins.index')->with('error', 'Failed to enable plugin: ' . $e->getMessage());
        }
    }

    public function disable(Request $request): RedirectResponse
    {
        $request->validate([
            'name' => 'required|string',
        ]);

        try {
            $this->pluginService->disablePlugin($request->input('name'));
            return redirect()->route('admin.arc.plugins.index')->with('success', 'Plugin disabled.');
        } catch (\Exception $e) {
            return redirect()->route('admin.arc.plugins.index')->with('error', 'Failed to disable plugin: ' . $e->getMessage());
        }
    }
}