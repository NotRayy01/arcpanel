<?php

namespace Pterodactyl\Providers;

use Illuminate\Support\ServiceProvider;
use Pterodactyl\Services\Arc\ArcPluginService;

class ArcServiceProvider extends ServiceProvider
{
    public function boot(): void
    {
        // Register plugin event hooks
        $this->app->make(ArcPluginService::class)->registerEventHooks();
    }

    public function register(): void
    {
        $this->app->singleton(ArcPluginService::class, function ($app) {
            return new ArcPluginService($app->make(\GuzzleHttp\Client::class));
        });
    }
}