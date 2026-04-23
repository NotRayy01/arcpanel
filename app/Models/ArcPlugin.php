<?php

namespace Pterodactyl\Models;

class ArcPlugin extends Model
{
    protected $table = 'arc_plugins';

    protected $fillable = [
        'name',
        'version',
        'enabled',
        'path',
        'installed_at',
    ];

    protected $casts = [
        'enabled' => 'boolean',
        'installed_at' => 'datetime',
    ];
}
