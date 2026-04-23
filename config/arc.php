<?php

return [
    'theme' => [
        'default' => [
            'name' => 'ArcPanel Default',
            'primary_color' => '#5865F2',
            'background' => '',
            'button_style' => 'rounded',
            'animations' => true,
        ],
    ],

    'plugin_registry_url' => env('ARCPANEL_PLUGIN_REGISTRY_URL', 'https://example.com/plugins.json'),
    'trusted_plugin_hosts' => array_filter(array_map('trim', explode(',', env('ARCPANEL_TRUSTED_PLUGIN_HOSTS', 'example.com')))),

    'social' => [
        'google' => [
            'client_id' => env('GOOGLE_CLIENT_ID'),
            'client_secret' => env('GOOGLE_CLIENT_SECRET'),
            'redirect' => env('APP_URL') . '/auth/social/google/callback',
        ],
        'discord' => [
            'client_id' => env('DISCORD_CLIENT_ID'),
            'client_secret' => env('DISCORD_CLIENT_SECRET'),
            'redirect' => env('APP_URL') . '/auth/social/discord/callback',
        ],
    ],
];
