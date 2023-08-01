//
//  SplashViewController.swift
//  ImageFeed
//
//  Created by Victoria Isaeva on 09.07.2023.
//

import UIKit
import ProgressHUD


final class SplashViewController: UIViewController {
    private let oauth2Service = OAuth2Service()
    private let oauth2TokenStorage = OAuth2TokenStorage()
    private let profileService = ProfileService.shared
    private let splashImage = UIImageView()
    private var splashImageView = UIImage(named:"splash_screen_logo")
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        setupSplashConstraints()
        view.backgroundColor = UIColor(named: "YP Black")
       // guard UIBlockingProgressHUD.isShowing == false else { return }
        
        if let token = oauth2TokenStorage.token {
            fetchProfile(token: token)
        } else {
            switchToAuthViewController()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setNeedsStatusBarAppearanceUpdate()
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }
    
    private func switchToTabBarController() {
        guard let window = UIApplication.shared.windows.first else {
            assertionFailure("Invalid Configuration")
            return
        }
        let tabBarController = UIStoryboard(name: "Main", bundle: .main)
            .instantiateViewController(withIdentifier: "TabBarViewController")
        window.rootViewController = tabBarController
    }
    
    private func switchToAuthViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let authViewController = storyboard.instantiateViewController(withIdentifier: "AuthViewController") as? AuthViewController else { return }
        authViewController.delegate = self
        authViewController.modalPresentationStyle = .fullScreen
        
        present(authViewController, animated: true)
    }
    
    private func showErrorAlert() {
        let alert = UIAlertController(
            title: "Что-то пошло не так",
            message: "Не удалось войти в систему",
            preferredStyle: .alert
        )
        let action = UIAlertAction(title: "Ок", style: .cancel) { [weak self] _ in
            guard let self else { return }
            self.switchToAuthViewController()
        }
        alert.addAction(action)
        present(alert, animated: true)
    }
}

extension SplashViewController: AuthViewControllerDelegate {
    func authViewController(_ vc: AuthViewController, didAuthenticateWithCode code: String) {
        dismiss(animated: true) { [ weak self ] in
            guard let self = self else { return }
            UIBlockingProgressHUD.show()
            
            self.fetchOAuthToken(code) { [weak self] result in
                switch result {
                case .success(let token):
                    self?.fetchProfile(token: token)
                case .failure:
                    DispatchQueue.main.async {
                        self?.showErrorAlert()
                        UIBlockingProgressHUD.dismiss()
                    }
                }
            }
        }
    }
    
    private func fetchOAuthToken(_ code: String,completion: @escaping (Result<String, Error>) -> Void) {
        UIBlockingProgressHUD.show()
        oauth2Service.fetchOAuthToken(code) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let token):
                oauth2TokenStorage.token = token
                
                completion(.success(token))
                self.fetchProfile(token: token)
                UIBlockingProgressHUD.dismiss()
                
            case .failure(let error):
                UIBlockingProgressHUD.dismiss()
                completion(.failure(error))
                    self.showErrorAlert()
            }
        }
    }
    
    
    private func fetchProfile(token: String) {
        profileService.fetchProfile(token) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let profile):
                ProfileImageService.shared.fetchProfileImageURL(userName: profile.userName ?? " ") { [weak self] _ in
                    self?.switchToTabBarController()
                }
            case .failure:
                self.showErrorAlert()
            }
            UIBlockingProgressHUD.dismiss()
        }
    }
    
    private func setupSplashConstraints() {
        splashImage.image = splashImageView
        splashImage.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(splashImage)
        
        NSLayoutConstraint.activate([
            splashImage.widthAnchor.constraint(equalToConstant: 72.5),
            splashImage.heightAnchor.constraint(equalToConstant: 75),
            splashImage.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            splashImage.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
    }
}
