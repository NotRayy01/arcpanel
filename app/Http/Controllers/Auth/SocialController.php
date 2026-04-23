<?php

namespace Pterodactyl\Http\Controllers\Auth;

use Pterodactyl\Models\User;
use Pterodactyl\Models\SocialAccount;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Laravel\Socialite\Facades\Socialite;
use Illuminate\Http\RedirectResponse;

class SocialController extends Controller
{
    public function redirect(string $provider): RedirectResponse
    {
        return Socialite::driver($provider)->redirect();
    }

    public function callback(string $provider): RedirectResponse
    {
        try {
            $socialUser = Socialite::driver($provider)->user();
        } catch (\Exception $e) {
            return redirect('/auth/login')->with('error', 'Unable to authenticate with ' . $provider);
        }

        $account = SocialAccount::where('provider', $provider)
            ->where('provider_id', $socialUser->getId())
            ->first();

        if ($account) {
            Auth::login($account->user);
            return redirect('/')->with('success', 'Logged in with ' . $provider);
        }

        // Check if user exists with email
        $user = User::where('email', $socialUser->getEmail())->first();

        if (!$user) {
            // Create new user
            $user = User::create([
                'email' => $socialUser->getEmail(),
                'username' => $socialUser->getNickname() ?: explode('@', $socialUser->getEmail())[0],
                'name_first' => explode(' ', $socialUser->getName())[0] ?? 'User',
                'name_last' => explode(' ', $socialUser->getName())[1] ?? '',
                'password' => Hash::make(str_random(16)), // Random password
            ]);
        }

        // Link account
        SocialAccount::create([
            'user_id' => $user->id,
            'provider' => $provider,
            'provider_id' => $socialUser->getId(),
            'provider_name' => $socialUser->getName(),
            'provider_data' => $socialUser->getRaw(),
        ]);

        Auth::login($user);
        return redirect('/')->with('success', 'Account linked and logged in with ' . $provider);
    }
}