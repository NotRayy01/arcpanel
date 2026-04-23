<?php

namespace Pterodactyl\Http\Controllers\Api\Client\Servers;

use Illuminate\Http\Response;
use Pterodactyl\Models\Server;
use Pterodactyl\Facades\Activity;
use Pterodactyl\Repositories\Wings\DaemonCommandRepository;
use Pterodactyl\Http\Controllers\Api\Client\ClientApiController;
use Illuminate\Http\Request;

class PlayerController extends ClientApiController
{
    public function __construct(private DaemonCommandRepository $repository)
    {
        parent::__construct();
    }

    public function ban(Request $request, Server $server): Response
    {
        $request->validate(['player' => 'required|string']);
        $this->repository->setServer($server)->send('ban ' . $request->input('player'));
        Activity::event('server:player.ban')->property('player', $request->input('player'))->log();
        return $this->returnNoContent();
    }

    public function unban(Request $request, Server $server): Response
    {
        $request->validate(['player' => 'required|string']);
        $this->repository->setServer($server)->send('pardon ' . $request->input('player'));
        Activity::event('server:player.unban')->property('player', $request->input('player'))->log();
        return $this->returnNoContent();
    }

    public function kick(Request $request, Server $server): Response
    {
        $request->validate(['player' => 'required|string']);
        $this->repository->setServer($server)->send('kick ' . $request->input('player'));
        Activity::event('server:player.kick')->property('player', $request->input('player'))->log();
        return $this->returnNoContent();
    }

    public function op(Request $request, Server $server): Response
    {
        $request->validate(['player' => 'required|string']);
        $this->repository->setServer($server)->send('op ' . $request->input('player'));
        Activity::event('server:player.op')->property('player', $request->input('player'))->log();
        return $this->returnNoContent();
    }

    public function deop(Request $request, Server $server): Response
    {
        $request->validate(['player' => 'required|string']);
        $this->repository->setServer($server)->send('deop ' . $request->input('player'));
        Activity::event('server:player.deop')->property('player', $request->input('player'))->log();
        return $this->returnNoContent();
    }
}