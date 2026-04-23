<?php

namespace Pterodactyl\Models;

use Illuminate\Database\Eloquent\Casts\AsArrayObject;

class ArcTheme extends Model
{
    protected $table = 'arc_themes';

    protected $fillable = [
        'name',
        'config',
        'is_default',
    ];

    protected $casts = [
        'config' => 'array',
        'is_default' => 'boolean',
    ];

    public function getConfigAttribute($value): array
    {
        return array_merge(config('arc.theme.default'), parent::getAttribute('config') ?? []);
    }
}
