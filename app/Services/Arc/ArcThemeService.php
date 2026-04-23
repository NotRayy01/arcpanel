<?php

namespace Pterodactyl\Services\Arc;

use Pterodactyl\Models\ArcTheme;
use Illuminate\Support\Arr;

class ArcThemeService
{
    public function getDefaultConfig(): array
    {
        return config('arc.theme.default');
    }

    public function getActiveTheme(): ArcTheme
    {
        if (! ArcTheme::query()->where('is_default', true)->exists()) {
            return $this->createDefaultTheme();
        }

        return ArcTheme::query()->where('is_default', true)->firstOrFail();
    }

    public function getActiveThemeConfig(): array
    {
        return $this->getActiveTheme()->config;
    }

    public function applyTheme(array $config): ArcTheme
    {
        $theme = $this->getActiveTheme();
        $theme->update([ 'config' => array_merge($theme->config, $this->normalizeConfig($config)) ]);
        return $theme;
    }

    protected function createDefaultTheme(): ArcTheme
    {
        return ArcTheme::query()->create([
            'name' => 'ArcPanel Default',
            'config' => $this->getDefaultConfig(),
            'is_default' => true,
        ]);
    }

    protected function normalizeConfig(array $config): array
    {
        return [
            'primary_color' => Arr::get($config, 'primary_color', $this->getDefaultConfig()['primary_color']),
            'background' => Arr::get($config, 'background', ''),
            'button_style' => Arr::get($config, 'button_style', 'rounded'),
            'animations' => filter_var(Arr::get($config, 'animations', true), FILTER_VALIDATE_BOOLEAN),
        ];
    }
}
