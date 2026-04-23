<?php

namespace Pterodactyl\Services\Arc;

use GuzzleHttp\Client;
use Pterodactyl\Models\ArcPlugin;
use ZipArchive;
use Illuminate\Support\Arr;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Pterodactyl\Exceptions\DisplayException;

class ArcPluginService
{
    public function __construct(private Client $client)
    {
    }

    public function fetchAvailablePlugins(): array
    {
        $url = config('arc.plugin_registry_url');
        $response = $this->client->get($url, ['timeout' => 10]);
        $data = json_decode((string) $response->getBody(), true);

        if (! is_array($data)) {
            return [];
        }

        return array_values(array_filter($data, fn ($plugin) => is_array($plugin) && isset($plugin['name'], $plugin['download_url'])));
    }

    public function getInstalledPlugins(): array
    {
        return ArcPlugin::all()->toArray();
    }

    public function installPlugin(string $name): ArcPlugin
    {
        $plugin = collect($this->fetchAvailablePlugins())->first(fn ($item) => $item['name'] === $name);
        if (! $plugin) {
            throw new DisplayException('Plugin not found in registry.');
        }

        $downloadUrl = $plugin['download_url'];
        $this->validatePluginUrl($downloadUrl);

        $temporaryPath = storage_path('app/arc_plugins/' . uniqid('arc_plugin_', true) . '.zip');
        if (! is_dir(dirname($temporaryPath))) {
            mkdir(dirname($temporaryPath), 0755, true);
        }

        $response = $this->client->get($downloadUrl, ['sink' => $temporaryPath, 'timeout' => 30]);
        if ($response->getStatusCode() !== 200) {
            throw new DisplayException('Unable to download plugin archive from registry.');
        }

        $archive = new ZipArchive();
        if ($archive->open($temporaryPath) !== true) {
            throw new DisplayException('Invalid plugin archive.');
        }

        $manifest = $this->loadManifest($archive);
        $pluginDirectory = Str::slug(Arr::get($manifest, 'name', $name));
        $destination = base_path('plugins/' . $pluginDirectory);

        $this->extractArchive($archive, $destination);
        $archive->close();
        @unlink($temporaryPath);

        return ArcPlugin::query()->updateOrCreate(
            ['name' => $pluginDirectory],
            [
                'version' => Arr::get($manifest, 'version', Arr::get($plugin, 'version', '1.0.0')),
                'enabled' => true,
                'path' => $pluginDirectory,
                'installed_at' => now(),
            ]
        );
    }

    public function enablePlugin(string $name): ArcPlugin
    {
        return $this->setPluginEnabledState($name, true);
    }

    public function disablePlugin(string $name): ArcPlugin
    {
        return $this->setPluginEnabledState($name, false);
    }

    public function getEnabledPlugins(): \Illuminate\Database\Eloquent\Collection
    {
        return ArcPlugin::query()->where('enabled', true)->get();
    }

    public function registerEventHooks(): void
    {
        foreach ($this->getEnabledPlugins() as $plugin) {
            $hookFile = base_path('plugins/' . $plugin->path . '/hooks.php');
            if (! file_exists($hookFile)) {
                continue;
            }

            try {
                $register = require $hookFile;
                if (is_callable($register)) {
                    $register(app('events'));
                }
            } catch (\Throwable $exception) {
                Log::warning('Failed to load plugin hook: ' . $plugin->name . ' - ' . $exception->getMessage());
            }
        }
    }

    protected function validatePluginUrl(string $url): void
    {
        $host = parse_url($url, PHP_URL_HOST);
        if (! $host) {
            throw new DisplayException('Plugin download URL is invalid.');
        }

        $allowed = config('arc.trusted_plugin_hosts', []);
        if (! in_array($host, $allowed, true)) {
            throw new DisplayException('Plugin URL host is not trusted.');
        }
    }

    protected function loadManifest(ZipArchive $archive): array
    {
        $manifestName = 'manifest.json';
        $index = $archive->locateName($manifestName, ZipArchive::FL_NODIR);
        if ($index === false) {
            throw new DisplayException('Plugin manifest.json is missing or invalid.');
        }

        $manifest = json_decode($archive->getFromIndex($index), true);
        if (! is_array($manifest) || empty($manifest['name']) || empty($manifest['main'])) {
            throw new DisplayException('Plugin manifest is malformed.');
        }

        return $manifest;
    }

    protected function extractArchive(ZipArchive $archive, string $destination): void
    {
        if (! is_dir($destination) && ! mkdir($destination, 0755, true) && ! is_dir($destination)) {
            throw new DisplayException('Unable to create plugin directory.');
        }

        for ($i = 0; $i < $archive->numFiles; $i++) {
            $entry = $archive->statIndex($i);
            $name = $entry['name'];
            $target = $destination . DIRECTORY_SEPARATOR . $name;
            $realDestination = realpath(dirname($target)) ?: dirname($target);
            if (! str_starts_with($realDestination, realpath($destination))) {
                throw new DisplayException('Plugin archive contains invalid file paths.');
            }
        }

        if (! $archive->extractTo($destination)) {
            throw new DisplayException('Unable to extract plugin archive.');
        }
    }

    protected function setPluginEnabledState(string $name, bool $enabled): ArcPlugin
    {
        $plugin = ArcPlugin::query()->where('name', $name)->first();
        if (! $plugin) {
            throw new DisplayException('Plugin not installed.');
        }

        $plugin->update(['enabled' => $enabled]);
        return $plugin;
    }
}
